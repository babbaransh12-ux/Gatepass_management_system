import 'package:flutter/material.dart';
class Uihelper {
  static CustomImage(
      {
    required String img,
        double width =300,
        double height= 300,
      }
  )
  {
    return Image.asset("assets/images/$img",
    width: width,
    height: height,
    fit: BoxFit.contain,
    );
  }
}