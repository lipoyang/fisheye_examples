package com.example.fisheye

import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // FisheyeViewをメイン画面に配置
        val fisheyeView = FisheyeView(this)
        setContentView(fisheyeView)
        //setContentView(R.layout.activity_main);
    }
}