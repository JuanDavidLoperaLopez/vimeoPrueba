//
//  APIRequest.swift
//  Combate Space
//
//  Created by DariusVallejo on 5/12/16.
//  Copyright © 2016 Juan Felipe Gallo. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON


extension Request {
	public static func JSONSwiftSerialize(
		options options: NSJSONReadingOptions = .AllowFragments)
		-> ResponseSerializer<JSON?, NSError> {

			return ResponseSerializer { _, response, data, error in
                if let error = error {
                    print("error serialize with data",data)
				 return .Failure(error)
				}

				if let response = response where response.statusCode == 204 { return .Success(nil) }

				guard let validData = data where validData.length > 0 else {
					let failureReason = "JSON could not be serialized. Input data was nil or zero length."
                    let error = Error.errorWithCode(.JSONSerializationFailed, failureReason: failureReason)
                    print("error length with data",data)
					return .Failure(error)
				}

				do {
					let json = try NSJSONSerialization.JSONObjectWithData(validData, options: options)
					let swiftJson = JSON(json)
					return .Success(swiftJson)
				} catch {
                    print("error json with data",data)
					return .Failure(error as NSError)
				}
			}
	}

	public func responseSwiftyJSON(
		queue queue: dispatch_queue_t? = nil,
        options: NSJSONReadingOptions = .AllowFragments,
        completionHandler: Response<JSON?, NSError> -> Void)
		-> Self {
			return response(
				queue: queue,
				responseSerializer: Request.JSONSwiftSerialize(options: options),
				completionHandler: completionHandler
			)
	}
}



public class APIRequest {

	typealias ApiDictionary = [String: AnyObject]


	static let manager: Manager = {
        
       let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        
        configuration
            .HTTPAdditionalHeaders = [
            "Content-Type": "application/json"
           // "Accept": "application/json" //Optional
        ]
        
       // configuration.requestCachePolicy = .ReloadIgnoringCacheData
        
//		let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
//		configuration
//            .HTTPAdditionalHeaders = Alamofire.Manager.defaultHTTPHeaders
//        
//        configuration.HTTPAdditionalHeaders?
//            .updateValue("application/json",forKey: "Accept")!
//        
//       configuration.HTTPAdditionalHeaders?
//            .updateValue("application/json",forKey: "Content-Type")
        
		return Alamofire.Manager(configuration: configuration)
	}()

	static func jsonErrorParse(json: JSON) -> ApiErrorType? {

		guard json["err"].bool == true,
			let code = json["code"].string
			where code != "successful" else {
				//if no err or code, then there is no error
				return nil
		}

		if let error = APIAuthError(rawValue: code) {
			return error
		}

		return APICodeError(json: json, code: code)

	}

	static func setAuthToken(to accessToken: String?) {
		Router.OAuthToken = accessToken
	}

    
	enum Router: URLRequestConvertible {
        static let baseURLString = "https://www.bwgamestudios.com/combatespaceapp/api"
		static var OAuthToken: String?

		case GetUsers([String: AnyObject])
		case GetLegacyPolicy
		case getQuestionCategories
		case updateImage
		case getParameters
		case getLanguageVariables(String)
		case RegisterNotificationToken(String)

		var method: Alamofire.Method {
			switch self {
			case .GetUsers, .GetLegacyPolicy, getQuestionCategories, .getLanguageVariables, .getParameters:
				return .GET
			case .updateImage, .RegisterNotificationToken:
				return .POST
			}
		}

		var path: String {
			switch self {
			case .GetUsers:
				return "/"
			case .GetLegacyPolicy:
				return "/legacy-policy"
			case .updateImage:
				return "/user/update-image"
			case .RegisterNotificationToken:
				return "/user/token-device-registration"
			case getQuestionCategories:
				return "/question-category/feed"
			case getLanguageVariables(let language):
				return "/internationalization-values/\(language)"
			case .getParameters:
				return "/parameters"
			}
		}

		var query: [String: AnyObject]? {
			switch self {
			case .GetUsers(let query):
				return query
			case .RegisterNotificationToken(let token):
				return [
				"deviceType":"iOS",
				"deviceToken": token
				]
			default:
				return nil
			}
		}

		// MARK: URLRequestConvertible

		var URLRequest: NSMutableURLRequest {
			let URL = NSURL(string: Router.baseURLString)!
			var mutableURLRequest = NSMutableURLRequest(URL: URL.URLByAppendingPathComponent(path))
			mutableURLRequest.HTTPMethod = method.rawValue

			if let token = Router.OAuthToken {
				mutableURLRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
			}

			if let query = query {
				mutableURLRequest = Alamofire.ParameterEncoding.URL.encode(mutableURLRequest, parameters: query).0
			}
			return mutableURLRequest
		}
	}
}
