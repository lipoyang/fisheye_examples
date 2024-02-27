from numba import jit
from tkinter import *
from PIL import Image, ImageTk
import math
import os
# import numpy as np
import time #デバッグ用

# ビットマップファイルのパス
dir_path = os.path.dirname(__file__)
image_path = os.path.join(dir_path, "lena_std.bmp")

# Pillowを使用して画像を開く
src_img = Image.open(image_path)
# src_data = np.array(src_img)
src_data = src_img.load()


# 画像のサイズ
W, H = src_img.size

dst_img = Image.new('RGB', (W, H))
dst_data = dst_img.load()

# レンズの半径
RAD = int(W * 0.6)

R = [[0, 0], [0, 0]]
G = [[0, 0], [0, 0]]
B = [[0, 0], [0, 0]]

# レンズの中心から投影面までの距離
D = int(RAD * 0.3)  # 小さいほど大きく歪む

# レンズの中心座標
x0 = W // 2
y0 = H // 2

def interpolation(x, y):
    X = int(x)
    Y = int(y)

    for i in range(2):
        for j in range(2):
            _x = X + i
            if _x >= W: _x = X
            _y = Y + j
            if _y >= H: _y = Y
            #pixel = src_img.getpixel((_x, _y))
            #R[i][j] = pixel[0]
            #G[i][j] = pixel[1]
            #B[i][j] = pixel[2]

            R[i][j], G[i][j], B[i][j] = src_data[_x, _y]
            #R[i][j] = 255
            #G[i][j] = 0
            #B[i][j] = 0

    dX = x - X
    dY = y - Y
    MdX = 1 - dX
    MdY = 1 - dY

    r = round(MdX * (MdY * R[0][0] + dY * R[0][1]) + dX * (MdY * R[1][0] + dY * R[1][1]))
    g = round(MdX * (MdY * G[0][0] + dY * G[0][1]) + dX * (MdY * G[1][0] + dY * G[1][1]))
    b = round(MdX * (MdY * B[0][0] + dY * B[0][1]) + dX * (MdY * B[1][0] + dY * B[1][1]))

    return r, g, b

def draw():
    start_time = time.time()

    global x0, y0

    for Y in range(H):
        for X in range(W):
            dX = X - x0
            dY = Y - y0
            d = math.sqrt(dX * dX + dY * dY)

            if d < RAD:
                Z = math.sqrt(RAD * RAD - dX * dX - dY * dY)
                x = x0 + (D * dX) / Z
                y = y0 + (D * dY) / Z

                if 0 <= x < W and 0 <= y < H:
                    color_val = interpolation(x, y)
                    #dst_img.putpixel((X, Y), color_val)
                    #dst_img.putpixel((X, Y), (0, 0, 0))
                    dst_data[X,Y] = color_val
                else:
                    dst_img.putpixel((X, Y), (0, 0, 0))
                    dst_data[X,Y] = (0, 0, 0)
            else:
                dst_img.putpixel((X, Y), (0, 0, 0))
                dst_data[X,Y] = (0, 0, 0)

    img_tk = ImageTk.PhotoImage(dst_img)
    label.config(image=img_tk)
    label.image = img_tk

    end_time = time.time()
    elapsed_time = end_time - start_time
    print(f"time: {elapsed_time} sec")


def mouse_pressed(event):
    global x0, y0
    x0, y0 = event.x, event.y
    print("x0:", x0, " y0:", y0)
    draw()


# Tkinterウィンドウの作成
root = Tk()
root.title("Image Distortion")

# 画像を表示するラベルの作成
label = Label(root)
label.pack()

# マウスクリックイベントのバインディング
root.bind("<Button-1>", mouse_pressed)

# ウィンドウのメインループ
draw()
root.mainloop()
