let srcImg; // 元画像
let dstImg; // 処理後の画像
let W,H; // 画像のサイズ
let RAD; // レンズの半径
let D; // レンズの中心から投影面までの距離
let x0,y0; // レンズの中心座標

// キャンバスとコンテキスト
const srcCanvas = document.createElement('canvas');
const srcContext = srcCanvas.getContext('2d');
const dstCanvas = document.getElementById('dstCanvas');
const dstContext = dstCanvas.getContext('2d');

const BLACK = [0, 0, 0, 255]; // 黒色
let x0_prev, y0_prev; // レンズの中心座標の前回値
let W2, H2; // 表示サイズ (画像サイズより画面が小さい場合があるため)
let mag; // 倍率 (画像横幅 / 表示横幅)
let R, G, B; // 線形補間用のバッファ (高速化のためグローバル変数に)

// 初期化
window.onload = function() {
  // 線形補間用のバッファ (高速化のためグローバル変数に)
  R = new Array(2);
  G = new Array(2);
  B = new Array(2);
  for(let i = 0; i <= 1; i++) {
    R[i] = new Array(2);
    G[i] = new Array(2);
    B[i] = new Array(2);
  }
  // 画像読み込み
  const img = new Image();
  img.crossOrigin = "anonymous";
  img.src = "./lena_std.bmp";
  img.onload = function () {
    // 画像サイズ
    W = img.width;
    H = img.height;
    RAD = Math.floor(W * 0.6);
    D = Math.floor(RAD * 0.3); // 小さいほど大きく歪む

    // 画像データの取得
    srcCanvas.width = W;
    srcCanvas.height = H;
    srcContext.drawImage(img, 0, 0);
    srcImg = srcContext.getImageData(0, 0, W, H);

    // 表示サイズ (画像サイズより画面が小さい場合があるため)
    W2 = W;
    H2 = H;
    mag = 1;
    const cW = Math.floor(document.documentElement.clientWidth  * 0.96);
    const cH = Math.floor(document.documentElement.clientHeight * 0.96);
    const cL = (cW < cH) ? cW : cH;
    if(cL < W){
      W2 = H2 = cL;
      mag = W / W2;
    }
    dstCanvas.width = W2;
    dstCanvas.height = H2;
    dstImg = dstContext.createImageData(W2, H2);

    // レンズの中心座標の初期値は中央
    x0 = W2 / 2;
    y0 = H2 / 2;
    x0_prev = 0;
    y0_prev = 0;

    // 描画開始
    draw();
  };
};

// マウスイベント
dstCanvas.addEventListener("mousedown", function (e) {
  x0 = e.offsetX;
  y0 = e.offsetY;
}); 
dstCanvas.addEventListener("mouseup", function (e) {
  x0 = e.offsetX;
  y0 = e.offsetY;
}); 
dstCanvas.addEventListener("mousemove", function (e) {
  if (e.buttons == 1){
    x0 = e.offsetX;
    y0 = e.offsetY;
  }
});

// タッチイベント
dstCanvas.addEventListener("touchstart", onTouch);
dstCanvas.addEventListener("touchend" ,  onTouch);
dstCanvas.addEventListener("touchmove",  onTouch);
function onTouch(e){
  e.preventDefault(); // デフォルトイベントをキャンセル
  if(e.touches.length > 1) return; // マルチタッチ非対応

  const bcr = e.target.getBoundingClientRect();
  x0 = e.changedTouches[0].clientX - bcr.x;
  y0 = e.changedTouches[0].clientY - bcr.y;
}

// 描画
function draw(){
  if (x0 <  0 ) x0 = 0;
  if (x0 >= W2) x0 = W2 - 1;
  if (y0 <  0 ) y0 = 0;
  if (y0 >= H2) y0 = H2 - 1;
  
  // レンズの中心座標が変化していなければ描画しない
  if((x0 == x0_prev) && (y0 == y0_prev)){
    requestAnimationFrame(draw); // 次回の描画
    return;
  }
  x0_prev = x0;
  y0_prev = y0;
  //console.log("draw");
  //const startTime = performance.now();

  // 写像後の座標
  for(let Y = 0; Y < H2; Y++){
    for(let X = 0; X < W2; X++){
      let c;
      
      // レンズの中心からの相対座標
      const dX = (X - x0) * mag;
      const dY = (Y - y0) * mag;
      const d = Math.sqrt(dX*dX + dY*dY);
      if(d < RAD){
        // 写像:元画像→魚眼画像
        // X = R*x/√(D^2+x^2+y^2)
        // Y = R*y/√(D^2+x^2+y^2)
        // 逆写像:魚眼画像→元画像
        // x = D*X/√(R^2-X^2-Y^2)
        // y = D*Y/√(R^2-X^2-Y^2)
        const Z = Math.sqrt(RAD*RAD - dX*dX - dY*dY);
        const x = x0*mag + (D * dX) / Z;
        const y = y0*mag + (D * dY) / Z;
        
        if(x >= 0 && x < W && y >= 0 && y < H){
          c = interpolation(x, y); // 元画像から線形補間で色を取得
        }else{
          c = BLACK; // 元画像の外側なら黒塗り
        }
      }else{
        c = BLACK; // レンズの外側なら黒塗り
      }
      const index = (Y * W2 + X) * 4;
      for(let i = 0; i < 4; i++) dstImg.data[index + i] = c[i];
    }
  }
  dstContext.putImageData(dstImg, 0, 0);

  //const endTime = performance.now();
  //console.log(endTime - startTime); // 何ミリ秒かかったか

  requestAnimationFrame(draw); // 次回の描画
}

// 線形補間
function interpolation(x, y)
{
  const X = Math.floor(x);
  const Y = Math.floor(y);

  for(let i = 0; i <= 1; i++){
    for(let j = 0; j <= 1; j++){
      let _x = X + i; if (_x >= W) _x = X;
      let _y = Y + j; if (_y >= H) _y = Y;
      const index = (_y * W + _x) * 4;
      R[i][j] = srcImg.data[index];
      G[i][j] = srcImg.data[index+1];
      B[i][j] = srcImg.data[index+2];
    }
  }
  const dX = x - Math.floor(x);
  const dY = y - Math.floor(y);
  const MdX = 1 - dX;
  const MdY = 1 - dY;
  const r = Math.round(MdX * (MdY * R[0][0] + dY * R[0][1]) + dX * (MdY * R[1][0] + dY * R[1][1]));
  const g = Math.round(MdX * (MdY * G[0][0] + dY * G[0][1]) + dX * (MdY * G[1][0] + dY * G[1][1]));
  const b = Math.round(MdX * (MdY * B[0][0] + dY * B[0][1]) + dX * (MdY * B[1][0] + dY * B[1][1]));
  const c = [r, g, b, 255];
  return c;
}
