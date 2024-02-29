package com.example.fisheye;

import androidx.appcompat.app.AppCompatActivity;

import android.os.Bundle;

public class MainActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // FisheyeViewをメイン画面に配置
        FisheyeView fisheyeView = new FisheyeView(this);
        setContentView(fisheyeView);
        //setContentView(R.layout.activity_main);
    }
}