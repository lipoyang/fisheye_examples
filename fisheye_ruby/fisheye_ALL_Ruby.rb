require 'gosu'
require 'chunky_png'
include Math

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
    }.flatten.pack('C*').bytes

    @W = src_img.width  # 画像の幅
    @H = src_img.height # 画像の高さ
    @RAD = @W * 0.6  # レンズの半径
    @D = @RAD * 0.3  # レンズの中心から投影面までの距離　(小さいほど大きく歪む)

    # 処理後の画像
    @dst_data = Array.new(@H*@W, 0x00000000)

    # レンズの中心座標の初期値は中央
    @x0 = @W / 2
    @y0 = @H / 2
    @x0_prev = 0
    @y0_prev = 0
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

    GC.disable
    # start_time = Time.now

    #ローカル変数のほうがいくぶんか高速
    _W, _H, _x0, _y0, _R2, _D = @W, @H, @x0, @y0, @RAD*@RAD, @D
    # 写像後の各々の点について
    pixelNum = @H * @W
    pindex = 0
    while pindex < pixelNum do # 2重より1重、forよりwhileのほうが高速
      # 写像後の座標
      _Y = pindex / _W
      _X = pindex % _W
      # レンズの中心からの相対座標
      dX = _X - _x0
      dY = _Y - _y0
      d2 = dX * dX + dY * dY
      if d2 < _R2
        # 写像:元画像→魚眼画像
        # X = R*xf/√(D^2+x^2+y^2)
        # Y = R*y/√(D^2+x^2+y^2)
        # 逆写像:魚眼画像→元画像
        # x = D*X/√(R^2-X^2-Y^2)
        # y = D*Y/√(R^2-X^2-Y^2)
        _Z = sqrt(_R2 - dX * dX - dY * dY)
        x = _x0 + (_D * dX) / _Z
        y = _y0 + (_D * dY) / _Z

        if 0 <= x && x < _W && 0 <= y && y < _H
          # 元画像から線形補間で色を取得
          @dst_data[pindex] = interpolation(x, y, _W, _H)
        else
          # 画像の外側なら黒塗り
          @dst_data[pindex] = 0xFF000000
        end
      else
        # レンズの外側なら黒塗り
        @dst_data[pindex] = 0xFF000000
      end
      pindex += 1
    end # while pindex < pixelNum do

    @dst_img = Gosu::Image.from_blob(@W, @H, @dst_data.pack('L*'))
    @dst_img.draw(10, 10, 0)

    # elapsed_time = Time.now - start_time
    # puts "time: #{elapsed_time} sec"
    GC.enable
  end

  # 線形補間
  def interpolation(x, y, _W, _H)
    _R = Array.new(4)
    _G = Array.new(4)
    _B = Array.new(4)
    _X = x.to_i
    _Y = y.to_i
    index = 0
    while index < 4 do # 2重より1重、forよりwhileのほうが高速
      i = index / 2
      j = index % 2
      _x = _X + i; _x = _X if _x >= _W
      _y = _Y + j; _y = _Y if _y >= _H
      pindex = (_y * _W + _x) * 3
      _R[index] = @src_data[pindex]
      _G[index] = @src_data[pindex + 1]
      _B[index] = @src_data[pindex + 2]
      index += 1
    end

    dX = x - _X
    dY = y - _Y
    mdX = 1 - dX
    mdY = 1 - dY
    r = ((mdX * (mdY * _R[0] + dY * _R[1]) + dX * (mdY * _R[2] + dY * _R[3])) ).round
    g = ((mdX * (mdY * _G[0] + dY * _G[1]) + dX * (mdY * _G[2] + dY * _G[3])) ).round
    b = ((mdX * (mdY * _B[0] + dY * _B[1]) + dX * (mdY * _B[2] + dY * _B[3])) ).round

    0xFF000000 | ((b << 16) & 0xFF0000) | ((g << 8) & 0xFF00) | (r & 0xFF)
  end

end # class MyWindow < Gosu::Window

window = MyWindow.new
window.show
