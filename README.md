Simple full screen UIImage viewer

## Installation

### Carthage

Simply add the dependency to your `Cartfile`

```
github "Tovkal/ImageViewer"
```

then `carthage update` and add it to your project.

### Cocoapods

Add the following to your `Podfile`

```
pod 'ImageViewer', :git => 'https://github.com/tovkal/ImageViewer'
```


## Usage

Simply pass the `UIImageView` you want to display and the VC presenting ImageViewer, where the `imageView` is currently displayed.

```Swift
ImageViewer.showImage(imageView: imageView, presentingVC: self)
```
