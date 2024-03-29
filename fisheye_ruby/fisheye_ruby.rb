require 'gosu'
require 'chunky_png'
require 'fiddle/import'
include Math

# Cのライブラリ
module CFunc
  extend Fiddle::Importer
  dlload File.expand_path("fisheye_clib.so", __dir__)
  extern 'void begin(uint8_t* src, int w, int h)'
  extern 'uint32_t* calc(int x0, int y0)'
end

# Gosuのウインドウクラス定義
class MyWindow < Gosu::Window

  # 初期化
  def initialize
    super 532, 532
    self.caption = "魚眼変換"

    # 元画像を開く
    dir_path = File.dirname(__FILE__)
    image_path = File.join(dir_path, "lena_std.png")
    src_img = ChunkyPNG::Image.from_file(image_path)
    @src_data = src_img.pixels.map {
      |pixel| [ChunkyPNG::Color.r(pixel), ChunkyPNG::Color.g(pixel), ChunkyPNG::Color.b(pixel)]
    }.flatten.pack('C*')

    @W = src_img.width  # 画像の幅
    @H = src_img.height # 画像の高さ

    # レンズの中心座標の初期値は中央
    @x0 = @W / 2
    @y0 = @H / 2
    @x0_prev = 0
    @y0_prev = 0

    # Cライブラリの初期化
    CFunc.begin(@src_data, @W, @H)
  end

  # マウスイベント
  def button_down(id)
    if id == Gosu::MsLeft
      @x0, @y0 = mouse_x - 10 , mouse_y - 10;
    end
  end
  def button_up(id)
    if id == Gosu::MsLeft
      @x0, @y0 = mouse_x - 10 , mouse_y - 10;
    end
  end
  # 更新
  def update
    if button_down?(Gosu::MsLeft)
      @x0, @y0 = mouse_x - 10 , mouse_y - 10;
    end
  end

  # 描画
  def draw
    @x0 = 0      if @x0 < 0
    @x0 = @W - 1 if @x0 >= @W
    @y0 = 0      if @y0 < 0
    @y0 = @H - 1 if @y0 >= @H

    # レンズの中心座標が変化していなければ再計算しない
    if @x0 == @x0_prev && @y0 == @y0_prev
      @dst_img.draw(10, 10, 0)
      return
    end
    @x0_prev = @x0
    @y0_prev = @y0

    #start_time = Time.now

    # Cライブラリで魚眼変換を計算
    dst_data = CFunc.calc(@x0, @y0).to_s(@W*@H*4)

    @dst_img = Gosu::Image.from_blob(@W, @H, dst_data)
    @dst_img.draw(10, 10, 0)

    #elapsed_time = Time.now - start_time
    #puts "time: #{elapsed_time} sec"
  end

end # class MyWindow < Gosu::Window

window = MyWindow.new
window.show
