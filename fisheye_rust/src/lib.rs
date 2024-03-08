use std::rc::Rc;
use std::cell::Cell;
use std::cell::RefCell;
use std::ops::Deref;
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;
use web_sys::console;
use web_sys::{CanvasRenderingContext2d, HtmlCanvasElement, HtmlImageElement, ImageData};
use wasm_bindgen::Clamped;

// 定数
const BLACK: [u8; 4] = [0, 0, 0, 255]; // 黒色

// アプリケーションの変数
#[derive(Clone, Copy, Default)]
pub struct App {
    w: u32, // 元画像の幅
    h: u32, // 元画像の高さ
    r: f64, // レンズの半径
    d: f64, // レンズの中心から投影面までの距離
    x0: i32, // レンズの中心のx座標
    y0: i32, // レンズの中心のy座標
    x0_prev: i32, // レンズの中心のx座標の前回値
    y0_prev: i32, // レンズの中心のy座標の前回値
    w2: u32, // 表示画像の幅
    h2: u32, // 表示画像の高さ
    mag: f64, // 倍率 (画像横幅 / 表示横幅)
}

// 元画像のバイト列バッファ
static mut SRC_DATA: Vec<u8> = Vec::new();

// 初期化
#[wasm_bindgen(start)]
pub fn start() -> Result<(), JsValue>
{
//  console::log_1(&JsValue::from_str("Hello world!"));

    // アプリケーションの変数を初期化
    let app:App = Default::default();
    let app = Rc::new(Cell::new(app));

    // 表示用キャンバスとそのコンテキストを取得
    let document = web_sys::window().unwrap().document().unwrap();
    let dst_canvas = document.get_element_by_id("dstCanvas").unwrap();
    let dst_canvas = dst_canvas
        .dyn_into::<HtmlCanvasElement>()
        .map_err(|_| ())
        .unwrap();
    let dst_context = dst_canvas
        .get_context("2d")
        .unwrap()
        .unwrap()
        .dyn_into::<CanvasRenderingContext2d>()
        .unwrap();
    let dst_context = Rc::new(dst_context); // TODO

    // マウスイベント
    {
        let app = app.clone();
        let dst_context = dst_context.clone();
        let mouse_updown = Closure::wrap(Box::new(move |e: web_sys::MouseEvent| {
            let mut _app = app.get();
            _app.x0 = e.client_x();
            _app.y0 = e.client_y();
            // 描画
            draw(&mut _app, &dst_context);
            app.set(_app);
        }) as Box<dyn FnMut(web_sys::MouseEvent)>);
        dst_canvas.set_onmousedown(Some(mouse_updown.as_ref().unchecked_ref()));
        dst_canvas.set_onmouseup  (Some(mouse_updown.as_ref().unchecked_ref()));
        mouse_updown.forget();
    }
    {
        let app = app.clone();
        let dst_context = dst_context.clone();
        let mouse_move = Closure::wrap(Box::new(move |e: web_sys::MouseEvent| {
            if e.buttons() == 1 {
                let mut _app = app.get();
                _app.x0 = e.client_x();
                _app.y0 = e.client_y();
                // 描画
                draw(&mut _app, &dst_context);
                app.set(_app);
            }
        }) as Box<dyn FnMut(web_sys::MouseEvent)>);
        dst_canvas.set_onmousemove(Some(mouse_move.as_ref().unchecked_ref()));
        mouse_move.forget();
    }
    // タッチイベント
    {
        let app = app.clone();
        let dst_context = dst_context.clone();
        let touch_move = Closure::wrap(Box::new(move |e: web_sys::TouchEvent| {
            let mut _app = app.get();
            let touches = e.touches();
            if touches.length() > 0 {
                if let Some(touch) = touches.item(0) {
                    _app.x0 = touch.client_x();
                    _app.y0 = touch.client_y();
                    // 描画
                    draw(&mut _app, &dst_context);
                    app.set(_app);
                }
            }
        }) as Box<dyn FnMut(web_sys::TouchEvent)>);
        dst_canvas.set_ontouchstart(Some(touch_move.as_ref().unchecked_ref()));
        dst_canvas.set_ontouchend  (Some(touch_move.as_ref().unchecked_ref()));
        dst_canvas.set_ontouchmove (Some(touch_move.as_ref().unchecked_ref()));
        touch_move.forget();
    }

    // 画像読み込み
    let src_image = HtmlImageElement::new().unwrap();
    let src_image = Rc::new(RefCell::new(src_image));
    {
        let _src_image = src_image.clone();
        let app = app.clone();
        let dst_context = dst_context.clone();
        
        // 画像ファイル読み込み完了時の処理
        let closure = Closure::once_into_js(move |_event: web_sys::Event| {
            // 画像データをimg要素として取得
            let src_image = Rc::try_unwrap(_src_image).unwrap().into_inner(); // TODO

            // 画面のサイズを取得
            let document = web_sys::window().unwrap().document().unwrap();
            let element = document.document_element().unwrap();
            let client_width = element.client_width();
            let client_height = element.client_height();
            
            let mut _app = app.get();

            // 画像サイズ
            _app.w = src_image.width();
            _app.h = src_image.height();
            _app.r = _app.w as f64 * 0.6;
            _app.d = _app.r * 0.3; // 小さいほど大きく歪む

            // 表示サイズ (画像サイズより画面が小さい場合があるため)
            _app.w2 = _app.w;
            _app.h2 = _app.h;
            _app.mag = 1.0;
            let c_w = ((client_width  as f64) * 0.96) as u32;
            let c_h = ((client_height as f64) * 0.96) as u32;
            let c_l = if c_w < c_h {c_w} else {c_h};
            if c_l < _app.w {
              _app.w2 = c_l;
              _app.h2 = c_l;
              _app.mag = (_app.w as f64) / (_app.w2 as f64);
            }
            // レンズの中心座標の初期値は中央
            _app.x0 = (_app.w2 / 2) as i32;
            _app.y0 = (_app.h2 / 2) as i32;
            _app.x0_prev = 0;
            _app.y0_prev = 0;

            app.set(_app);
            
            // 元画像のイメージデータを取得
            let src_canvas = document.create_element("canvas")
                .unwrap().dyn_into::<HtmlCanvasElement>().unwrap();
            let src_context = src_canvas.get_context("2d")
                .unwrap().unwrap().dyn_into::<CanvasRenderingContext2d>().unwrap();
            src_canvas.set_width(_app.w);
            src_canvas.set_height(_app.h);
            src_context.draw_image_with_html_image_element(&src_image, 0.0, 0.0).unwrap();
            let image_data = src_context.get_image_data(0.0, 0.0, _app.w as f64, _app.h as f64).unwrap();
            let image_data = image_data.data();
            let image_data = image_data.deref();
            unsafe{
                SRC_DATA.resize(image_data.len(), 0);
                SRC_DATA.clone_from_slice(&image_data);
            }
           
            // 表示画像のキャンバスサイズ設定
            dst_canvas.set_width(_app.w2);
            dst_canvas.set_height(_app.h2);
          
            // 描画
            draw(&mut _app, &dst_context);
        }); // TODO
        src_image.borrow_mut().set_onload(Some(closure.as_ref().unchecked_ref()));
        src_image.borrow_mut().set_src("./lena_std.bmp");
        // TODO
    }
    Ok(())
}

// 描画
fn draw(_app: &mut App,dst_context: &CanvasRenderingContext2d)
{
    let size = _app.h2 * _app.w2 * 4;
    let mut dst_data: Vec<u8> = vec![0; size as usize];
    
    let w = _app.w as i32;
    let h = _app.h as i32;
    let r = _app.r;
    let d = _app.d;
    let w2 = _app.w2 as i32;
    let h2 = _app.h2 as i32;
    let mag = _app.mag;
    let mut x0 = _app.x0;
    let mut y0 = _app.y0;

    if x0 <  0  { x0 = 0; } 
    if x0 >= w2 { x0 = w2 - 1 };
    if y0 <  0  { y0 = 0; }
    if y0 >= h2 { y0 = h2 - 1 };
    
    // レンズの中心座標が変化していなければ描画しない
    if (x0 == _app.x0_prev) && (y0 == _app.y0_prev) {
      // requestAnimationFrame(draw); // 次回の描画
      return;
    }
    _app.x0 = x0;
    _app.y0 = y0;
    _app.x0_prev = x0;
    _app.y0_prev = y0;

    let start_time = js_sys::Date::now();

    // 写像後の座標
    for y in 0..h2 {
        for x in 0..w2 {
            let c;
            
            // レンズの中心からの相対座標
            let dx = ((x - x0) as f64) * mag;
            let dy = ((y - y0) as f64) * mag;
            let _d = (dx*dx + dy*dy).sqrt();
            if _d < r {
                // 写像:元画像→魚眼画像
                // X = R*x/√(D^2+x^2+y^2)
                // Y = R*y/√(D^2+x^2+y^2)
                // 逆写像:魚眼画像→元画像
                // x = D*X/√(R^2-X^2-Y^2)
                // y = D*Y/√(R^2-X^2-Y^2)
                let z = (r*r - dx*dx - dy*dy).sqrt();
                let _x = (x0 as f64) * mag + (d * dx) / z;
                let _y = (y0 as f64) * mag + (d * dy) / z;
                
                if (_x >= 0.0) && (_x < w as f64) && (_y >= 0.0) && (_y < h as f64) {
                    c = interpolation(w as usize, h as usize, _x, _y); // 元画像から線形補間で色を取得
                }else{
                    c = BLACK; // 元画像の外側なら黒塗り
                }
            }else{
                c = BLACK; // レンズの外側なら黒塗り
            }
            let index = ((y * w2 + x) * 4) as usize;
            for i in 0..4 { dst_data[index + i] = c[i] };
        }
    }

    let dst_data = Clamped(&dst_data[..]);
    let dst_data = ImageData::new_with_u8_clamped_array_and_sh(dst_data, _app.w2, _app.h2).unwrap();
    dst_context.put_image_data(&dst_data, 0.0, 0.0).unwrap();

    let end_time = js_sys::Date::now();
    let elapsed_time = end_time - start_time;
    console::log_1(&JsValue::from_str(&format!("draw in {} msec", elapsed_time)));
}

// 線形補間
fn interpolation(w:usize, h:usize, x:f64, y:f64) -> [u8; 4]
{
    let mut r: [[f64; 2]; 2] = [[0.0; 2]; 2]; 
    let mut g: [[f64; 2]; 2] = [[0.0; 2]; 2]; 
    let mut b: [[f64; 2]; 2] = [[0.0; 2]; 2]; 

    let i_x = x as usize;
    let i_y = y as usize;

    for i in 0..=1 {
        for j in 0..= 1 {
            let mut _x = i_x + i; if _x >= w {_x = i_x;}
            let mut _y = i_y + j; if _y >= h {_y = i_y;}
            let index = (_y * w + _x) * 4;
            unsafe{
                r[i][j] = SRC_DATA[index  ] as f64;
                g[i][j] = SRC_DATA[index+1] as f64;
                b[i][j] = SRC_DATA[index+2] as f64;
            }
        }
    }
    let dx = x - i_x as f64;
    let dy = y - i_y as f64;
    let mdx = 1.0 - dx;
    let mdy = 1.0 - dy;
    let r = (mdx * (mdy * r[0][0] + dy * r[0][1]) + dx * (mdy * r[1][0] + dy * r[1][1])).round() as u8;
    let g = (mdx * (mdy * g[0][0] + dy * g[0][1]) + dx * (mdy * g[1][0] + dy * g[1][1])).round() as u8;
    let b = (mdx * (mdy * b[0][0] + dy * b[0][1]) + dx * (mdy * b[1][0] + dy * b[1][1])).round() as u8;
    let c = [r, g, b, 255];
    return c;
}