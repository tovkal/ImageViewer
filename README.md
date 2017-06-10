Simple full screen UIImage viewer

### Installation

Simply add the dependency to your `Cartfile`

```
github "Tovkal/ImageViewer"
```

then `carthage update` and add it to your project.

### Usage

Simply pass the `UIImageView` you want to display and the VC presenting ImageViewer, where the `imageView` is currently displayed.

```Swift
ImageViewer.showImage(imageView: imageView, presentingVC: self)
```
