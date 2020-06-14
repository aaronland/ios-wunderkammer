import Foundation

struct CooperHewittAPIResponse {
    var Data: Data
    var URLResponse: URLResponse
}

struct CooperHewittAPIError: Error {
    var Code: Int
    var Message: String
}

enum CooperHewittAPIErrors : Error {
    case missingData
    case missingResponse
    case unknownError
}

class CooperHewittAPI {
    
    public let auth_url = "https://collection.cooperhewitt.org/api/oauth2/authenticate/"
    public let token_url = "https://collection.cooperhewitt.org/api/oauth2/access_token/"
    
    var endpoint = "https://api.collection.cooperhewitt.org/rest/"
    var access_token: String?
    
    init(access_token: String) {
        self.access_token = access_token
    }
    
    init(endpoint: String, access_token: String) {
        self.endpoint = endpoint
        self.access_token = access_token
    }
    
    public func ExecuteMethod(method: String, params: [String:String], completion: @escaping (Result<CooperHewittAPIResponse, Error>)->()) {
        
        let url = URL(string: self.endpoint)!
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

        components.queryItems = [
            URLQueryItem(name: "method", value: method),
            URLQueryItem(name: "access_token", value: self.access_token),
        ]

        for (k, v) in params {
            components.queryItems?.append(URLQueryItem(name: k, value: v))
        }
        
        let query = components.url!.query
        
        let session = URLSession.shared
        var request = URLRequest(url: url)
        
        request.httpMethod = "POST"
        request.httpBody = Data(query!.utf8)

        let task = session.dataTask(with: request as URLRequest, completionHandler: { data, response, error in

            if error != nil {
                completion(.failure(error!))
                return
            }

            if data == nil {
                completion(.failure(CooperHewittAPIErrors.missingData))
                return
            }

            if response == nil {
                completion(.failure(CooperHewittAPIErrors.missingResponse))
                return
            }
            
            let http_rsp = response as! HTTPURLResponse
            
            if http_rsp.statusCode != 200 {
                
                guard let str_code = http_rsp.allHeaderFields["X-api-error-code"] else {
                    completion(.failure(CooperHewittAPIErrors.unknownError))
                    return
                 }
 
                guard let message = http_rsp.allHeaderFields["X-api-error-message"] else {
                    completion(.failure(CooperHewittAPIErrors.unknownError))
                    return
                 }

                guard  let code = Int(str_code as! String) else {
                    completion(.failure(CooperHewittAPIErrors.unknownError))
                    return
                }
                
                let api_error = CooperHewittAPIError(Code: code as Int, Message: message as! String)
                completion(.failure(api_error))
                return
            }
            
            let api_response = CooperHewittAPIResponse(Data: data!, URLResponse: response!)
            completion(.success(api_response))
        })
        
        task.resume()
    }
}
