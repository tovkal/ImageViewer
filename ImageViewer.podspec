Pod::Spec.new do |spec|
  spec.name = "ImageViewer"
  spec.version = "0.1.2"
  spec.summary = "Simple full screen UIImageView viewer."
  spec.description = <<-DESC
  Simple full screen UIImageView viewer, can be dismissed with a tap or flick
                   DESC
  spec.homepage = "https://github.com/Tovkal/ImageViewer"
  spec.license = { :type => 'MIT', :file => 'LICENSE' }
  spec.author = "Andrés Pizá Bückmann"
  spec.platform = :ios, '10.3'
  spec.source = { :git => "https://github.com/Tovkal/ImageViewer.git", :tag => "#{spec.version}" }
  spec.source_files = "ImageViewer"
  spec.swift_version = '4.2'
end
