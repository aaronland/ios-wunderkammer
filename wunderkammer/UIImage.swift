import UIKit

extension UIImage {
    
    func resizedImage(withBounds bounds: CGSize) -> UIImage {
        
        let horizontalRatio = bounds.width / size.width
        let verticalRatio = bounds.height / size.height
        let ratio = min(horizontalRatio, verticalRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, true, 0)
        draw(in: CGRect(origin: CGPoint.zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }
    
    func hasAlpha() -> Bool {
        guard let cgImage = cgImage else {
            return false
        }
        let alpha = cgImage.alphaInfo
        return alpha == .first || alpha == .last || alpha == .premultipliedFirst || alpha == .premultipliedLast
    }

    func dataURL() -> String? {
        var imageData: Data? = nil
        var mimeType: String? = nil

        if hasAlpha() {
            print("ALPHA")
            imageData = self.pngData()
            mimeType = "image/png"
        } else {
            print("JPEG")
            imageData = self.jpegData(compressionQuality: 1.0)
            mimeType = "image/jpeg"
        }

        return "data:\(mimeType ?? "");base64,\(imageData?.base64EncodedString(options: []) ?? "")"
    }
}
