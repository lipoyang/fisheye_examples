PImage srcImg; // 元画像
PImage dstImg; // 処理後の画像
int W,H; // 画像のサイズ
int R; // レンズの半径
int D; // レンズの中心から投影面までの距離
int x0,y0; // レンズの中心座標

// 初期化
void settings() {
  // Processing 3系ではsizeに変数を使う場合は
  // setup()でははくsettings()で
  srcImg = loadImage("lena_std.bmp");
  W = srcImg.width;
  H = srcImg.height;
  R = int(W * 0.6);
  D = int(R * 0.3); // 小さいほど大きく歪む
  dstImg = createImage(W, H, RGB);
  size(W, H);
  x0 = W / 2;
  y0 = H / 2;
}

void setup() {
}

// 描画
void draw() {
  // マウス座標をレンズの中心とする
  if(mousePressed){
    x0 = mouseX;
    y0 = mouseY;
    if (x0 <  0) x0 = 0;
    if (x0 >= W) x0 = W - 1;
    if (y0 <  0) y0 = 0;
    if (y0 >= H) y0 = H - 1;
  }

  // 写像前の座標
  float x,y;
  // 写像後の座標
  for(int Y = 0; Y < H; Y++){
    for(int X = 0; X < W; X++){
      color c;
      
      // レンズの中心からの相対座標
      int dX = X - x0;
      int dY = Y - y0;
      float d = sqrt(dX*dX + dY*dY);
      if(d < R){
        // 写像:元画像→魚眼画像
        // X = R*x/√(D^2+x^2+y^2)
        // Y = R*y/√(D^2+x^2+y^2)
        // 逆写像:魚眼画像→元画像
        // x = D*X/√(R^2-X^2-Y^2)
        // y = D*Y/√(R^2-X^2-Y^2)
        float Z = sqrt(R*R - dX*dX - dY*dY);
        x = x0 + (D * dX) / Z;
        y = y0 + (D * dY) / Z;
        
        if(x >= 0 && x < W && y >= 0 && y < H){
          c = interpolation(x, y); // 元画像から線形補間で色を取得
        }else{
          c = color(0); // 元画像の外側なら黒塗り
        }
      }else{
        c = color(0); // レンズの外側なら黒塗り
      }
      dstImg.set(X, Y, c);
    }
  }
  image(dstImg, 0, 0);
}

// 線形補間
color interpolation(float x, float y)
{
  int X = floor(x);
  int Y = floor(y);
  float[][] R = new float[2][2];
  float[][] G = new float[2][2];
  float[][] B = new float[2][2];
  for(int i = 0; i <= 1; i++){
    for(int j = 0; j <= 1; j++){
      int _x = X + i; if (_x >= W) _x = X;
      int _y = Y + j; if (_y >= H) _y = Y;
      color c = srcImg.get(_x, _y);
      R[i][j] = red(c);
      G[i][j] = green(c);
      B[i][j] = blue(c);
    }
  }
  float dX = x - floor(x);
  float dY = y - floor(y);
  float MdX = 1 - dX;
  float MdY = 1 - dY;
  int r = round(MdX * (MdY * R[0][0] + dY * R[0][1]) + dX * (MdY * R[1][0] + dY * R[1][1]));
  int g = round(MdX * (MdY * G[0][0] + dY * G[0][1]) + dX * (MdY * G[1][0] + dY * G[1][1]));
  int b = round(MdX * (MdY * B[0][0] + dY * B[0][1]) + dX * (MdY * B[1][0] + dY * B[1][1]));
  color ret = color(r, g, b);
  return ret;
}
