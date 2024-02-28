from numba import jit
from tkinter import *
from PIL import Image, ImageTk
import numpy as np
import math
import os
import time #デバッグ用

# 元画像を開く
dir_path = os.path.dirname(__file__)
image_path = os.path.join(dir_path, "lena_std.bmp")
src_img = Image.open(image_path)
src_data = np.asarray(src_img)

W, H = src_img.size # 画像のサイズ
RAD = int(W * 0.6)  # レンズの半径
D = int(RAD * 0.3)  # レンズの中心から投影面までの距離　(小さいほど大きく歪む)

# 処理後の画像
dst_img = Image.new('RGB', (W, H))
dst_data = np.zeros((H, W, 3), dtype=np.uint8)

# レンズの中心座標の初期値は中央
x0 = W // 2
y0 = H // 2
x0_prev = 0
y0_prev = 0

# 描画
def draw():
    global dst_data, x0, y0, x0_prev, y0_prev

    if x0 <  0: x0 = 0
    if x0 >= W: x0 = W - 1
    if y0 <  0: y0 = 0
    if y0 >= H: y0 = H - 1

    # レンズの中心座標が変化していなければ描画しない
    if x0 == x0_prev and y0 == y0_prev:
        return
    x0_prev = x0
    y0_prev = y0

    start_time = time.time()

    # 描画サブルーチン
    draw_sub(x0, y0, dst_data)

    dst_img = Image.fromarray(dst_data)
    img_tk = ImageTk.PhotoImage(dst_img)
    label.config(image=img_tk)
    label.image = img_tk

    end_time = time.time()
    elapsed_time = end_time - start_time
    print(f"time: {elapsed_time} sec")

# 描画サブルーチン
@jit(nopython=True)
def draw_sub(x0, y0, dst_data):
    # dst_data = np.zeros((H, W, 3), dtype=np.uint8) # 方法5

    # 写像後の座標
    for Y in range(H):
        for X in range(W):
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
                    dst_data[Y, X] = interpolation(x, y) # 元画像から線形補間で色を取得
                else:
                    dst_data[Y, X] = (0, 0, 0) # 画像の外側なら黒塗り
            else:
                dst_data[Y, X] = (0, 0, 0) # レンズの外側なら黒塗り

# 線形補間
@jit(nopython=True)
def interpolation(x, y):
    R = np.zeros((2, 2))
    G = np.zeros((2, 2))
    B = np.zeros((2, 2))

    X = int(x)
    Y = int(y)
    for i in range(2):
        for j in range(2):
            _x = X + i
            if _x >= W: _x = X
            _y = Y + j
            if _y >= H: _y = Y
            R[i, j] = src_data[_y, _x, 0]
            G[i, j] = src_data[_y, _x, 1]
            B[i, j] = src_data[_y, _x, 2]            
    dX = x - X
    dY = y - Y
    MdX = 1 - dX
    MdY = 1 - dY
    r = round(MdX * (MdY * R[0, 0] + dY * R[0, 1]) + dX * (MdY * R[1, 0] + dY * R[1, 1]))
    g = round(MdX * (MdY * G[0, 0] + dY * G[0, 1]) + dX * (MdY * G[1, 0] + dY * G[1, 1]))
    b = round(MdX * (MdY * B[0, 0] + dY * B[0, 1]) + dX * (MdY * B[1, 0] + dY * B[1, 1]))
    return r, g, b

# マウスイベント
def mouse_updown(event):
    global x0, y0
    x0, y0 = event.x, event.y
    draw()
def mouse_move(event):
    global x0, y0
    button_state = event.state
    if button_state & 0x100:  # 左ボタン状態
        x0, y0 = event.x, event.y
        draw()

# Tkinterウィンドウ
root = Tk()
root.title("Image Distortion")
label = Label(root) # 画像を表示するラベル
label.pack()
root.bind("<Button-1>",        mouse_updown)
root.bind('<ButtonRelease-1>', mouse_updown)
root.bind('<Motion>',          mouse_move)

draw()
root.mainloop()
