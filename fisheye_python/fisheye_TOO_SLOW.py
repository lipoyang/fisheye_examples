# [メモ1]
# 方法1: Image.getpixel/putpixel  → 遅い
# 方法2: Image.load               → 方法1よりはかなり速く面倒もない
# 方法3: Image.getdata/putdata    → 方法2よりさらに速いが、少しだけ面倒
# 方法4: Image.tobytes/frombytes  → 方法3よりさらに面倒だが、速度の向上見られず
# → 方法1～4 の中では 方法3 がいちばんマシだが、 じゅうぶんな性能は得られず。

from tkinter import *
from PIL import Image, ImageTk
import math
import os
import time #デバッグ用

# 元画像を開く
dir_path = os.path.dirname(__file__)
image_path = os.path.join(dir_path, "lena_std.bmp")
src_img = Image.open(image_path)
# src_data = src_img.load()    # 方法2
src_data = src_img.getdata()   # 方法3
# src_data = src_img.tobytes() # 方法4

W, H = src_img.size # 画像のサイズ
RAD = int(W * 0.6)  # レンズの半径
D = int(RAD * 0.3)  # レンズの中心から投影面までの距離　(小さいほど大きく歪む)

# 処理後の画像
dst_img = Image.new('RGB', (W, H))
# dst_data = dst_img.load()           # 方法2
dst_data = [None] * len(src_data)     # 方法3
# dst_data = bytearray(len(src_data)) # 方法4

# 線形補間用のバッファ (高速化のためグローバル変数に)
R = [[0, 0], [0, 0]]
G = [[0, 0], [0, 0]]
B = [[0, 0], [0, 0]]

# レンズの中心座標の初期値は中央
x0 = W // 2
y0 = H // 2

# マウスイベント
def mouse_pressed(event):
    global x0, y0
    x0, y0 = event.x, event.y
    draw()

# 描画
def draw():
    global dst_data

    start_time = time.time()

    # 写像後の座標
    for Y in range(H):
        Y_offset = Y * W # 方法3,方法4
        for X in range(W):
            # index = (Y_offset + X) * 3 # 方法4

            # レンズの中心からの相対座標
            dX = X - x0
            dY = Y - y0
            d = math.sqrt(dX * dX + dY * dY)
            if d < RAD:
                # 写像:元画像→魚眼画像
                # X = R*xf/√(D^2+x^2+y^2)
                # Y = R*y/√(D^2+x^2+y^2)
                # 逆写像:魚眼画像→元画像
                # x = D*X/√(R^2-X^2-Y^2)
                # y = D*Y/√(R^2-X^2-Y^2)
                Z = math.sqrt(RAD * RAD - dX * dX - dY * dY)
                x = x0 + (D * dX) / Z
                y = y0 + (D * dY) / Z

                if 0 <= x < W and 0 <= y < H:
                    color_val = interpolation(x, y) # 元画像から線形補間で色を取得
                    # dst_img.putpixel((X, Y), color_val) # 方法1
                    # dst_data[X,Y] = color_val           # 方法2
                    dst_data[Y_offset + X] = color_val    # 方法3
                else:
                    # 画像の外側なら黒塗り
                    # dst_img.putpixel((X, Y), (0, 0, 0)) # 方法1
                    # dst_data[X,Y] = (0, 0, 0)           # 方法2
                    dst_data[Y_offset + X] = (0, 0, 0)    # 方法3
                    # color_val = (0, 0, 0)               # 方法4
            else:
                # レンズの外側なら黒塗り
                # dst_img.putpixel((X, Y), (0, 0, 0))     # 方法1
                # dst_data[X,Y] = (0, 0, 0)               # 方法2
                dst_data[Y_offset + X] = (0, 0, 0)        # 方法3
                # color_val = (0, 0, 0)                   # 方法4
            # 方法4
            # dst_data[index  ] = color_val[0]
            # dst_data[index+1] = color_val[1]
            # dst_data[index+2] = color_val[2]

    dst_img.putdata(dst_data)                                         # 方法3
    # dst_img = Image.frombytes('RGB', src_img.size, bytes(dst_data)) # 方法4
    img_tk = ImageTk.PhotoImage(dst_img)
    label.config(image=img_tk)
    label.image = img_tk

    end_time = time.time()
    elapsed_time = end_time - start_time
    print(f"time: {elapsed_time} sec")

# 線形補間
def interpolation(x, y):
    global R, G, B

    X = int(x)
    Y = int(y)
    for i in range(2):
        for j in range(2):
            _x = X + i
            if _x >= W: _x = X
            _y = Y + j
            if _y >= H: _y = Y
            # R[i][j], G[i][j], B[i][j] = src_img.getpixel((_x, _y)) # 方法1
            # R[i][j], G[i][j], B[i][j] = src_data[_x, _y]           # 方法2
            R[i][j], G[i][j], B[i][j] = src_data[_y * W + _x]        # 方法3
            # 方法4
            # index = (_y * W + _x) * 3
            # R[i][j] = src_data[index]
            # G[i][j] = src_data[index + 1]
            # B[i][j] = src_data[index + 2]
    dX = x - X
    dY = y - Y
    MdX = 1 - dX
    MdY = 1 - dY
    r = round(MdX * (MdY * R[0][0] + dY * R[0][1]) + dX * (MdY * R[1][0] + dY * R[1][1]))
    g = round(MdX * (MdY * G[0][0] + dY * G[0][1]) + dX * (MdY * G[1][0] + dY * G[1][1]))
    b = round(MdX * (MdY * B[0][0] + dY * B[0][1]) + dX * (MdY * B[1][0] + dY * B[1][1]))
    return r, g, b

# Tkinterウィンドウ
root = Tk()
root.title("魚眼変換 (遅い)")
label = Label(root) # 画像を表示するラベル
label.pack()
root.bind("<Button-1>", mouse_pressed) # マウスクリックイベント

draw()
root.mainloop()
