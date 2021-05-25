# Fractal Renderer of the Mandelbrot-Set

[<img align = "left" width = "170" height = "200" src = "https://raw.githubusercontent.com/johsteffens/xoimandel/master/images/Screenshot.png">](https://raw.githubusercontent.com/johsteffens/xoimandel/master/images/Screenshot.png "Screenshot" )

[<img align = "left" width = "216" height = "200" src = "https://raw.githubusercontent.com/johsteffens/xoimandel/master/images/image1.png">](https://raw.githubusercontent.com/johsteffens/xoimandel/master/images/image1.png "Sample 1" )

[<img align = "top" width = "203" height = "200" src = "https://raw.githubusercontent.com/johsteffens/xoimandel/master/images/image2.png">](https://raw.githubusercontent.com/johsteffens/xoimandel/master/images/image2.png "Sample 2" )

## What it is

XoiMandel is a simple and fast GUI based fractal rendering tool.

On startup it displays the main body of the Mandelbrot-Set. 
Navigation is easy and intuitive by using the mouse:

```
Zoom in or out:    Point + Scroll-Wheel
Move the fractal:  Point + Left-Click + Move
Change Resolution: Change Window Size
```

## Prerequisites

```
$ sudo apt install build-essential
$ sudo apt install libgtk-3-dev
```

## Getting Started

```
$ git clone https://github.com/johsteffens/beth
$ git clone https://github.com/johsteffens/xoico
$ git clone https://github.com/johsteffens/xoimandel
$ cd xoimandel
$ make
$ ./bin/xoimandel
```

## Changing the Color Model

The Renderer uses a predefined color model and histogram equalization.
However, a given position can be stored into a file and later reloaded.
That file is text-based and can be edited with a simple text editor.
To change the color model, locate the entry 'color_map' and change one
of the 9 associate values:

```
ra,rb,rc (for red)
ga,gb,gc (for green)
ba,bb,bc (for blue)
```
Save the file, reload it into XoiMandel and see what happens.

## License

XoiMandel is licensed under GPLv3+.

A fractal picture you create using XoiMandel is not limited by that license.
You may use, distribute or publish such pictures freely under your own terms.

## Motivation

Except for creating a nice and easy-to-use tool for mathematical recreation, 
this application shall also demonstrate
how to use the [beth-framework](https://github.com/johsteffens/beth) and
especially the programming language [xoila](https://github.com/johsteffens/beth#xoila).

------

<sub>&copy; Johannes B. Steffens</sub>
