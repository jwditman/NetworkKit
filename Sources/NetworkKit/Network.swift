//
//  Network.swift
//  
//
//  Created by Andre Navarro on 10/31/19.
//

import Foundation

public typealias TaskIdentifier = Int

public protocol NetworkType {
    // swiftlint:disable:next function_parameter_count
    func request(withBaseURL baseURL: URL,
                 path: String,
                 method: HTTPMethod,
                 bodyType: HTTPBodyType,
                 headerValues: HTTPHeaders?,
                 body: Encodable?,
                 queryParameters query: QueryParameters?) -> Request

    func request(_ url: URL?, method: HTTPMethod) -> Request
    func request(_ target: TargetType) -> Request
    func request(urlString: String, method: HTTPMethod) -> Request
    func request(_ urlRequest: URLRequest?) -> Request
}

extension NetworkType {
    public func request(urlString: String, method: HTTPMethod = .get) -> Request {
        return request(URL(string: urlString), method: method)
    }

    public func request(withBaseURL baseURL: URL,
                        path: String,
                        method: HTTPMethod,
                        bodyType: HTTPBodyType = .none,
                        headerValues: HTTPHeaders? = nil,
                        body: Encodable? = nil,
                        queryParameters query: QueryParameters? = nil) -> Request {

        return request(URLRequest(baseURL: baseURL,
                                  path: path,
                                  httpMethod: method,
                                  headerValues: headerValues,
                                  additionalHeaderValues: nil,
                                  queryParameters: query,
                                  bodyType: bodyType,
                                  body: body))
    }

    public func request(_ target: TargetType) -> Request {
        return request(target.asURLRequest())
    }

    public func request(_ url: URL?, method: HTTPMethod = .get) -> Request {
        var urlRequest: URLRequest?
        if let url = url {
            urlRequest = URLRequest(url: url)
            urlRequest?.httpMethod = method.value
        }

        return request(urlRequest)
    }

    public func request(_ urlString: String, method: HTTPMethod = .get) -> Request {
        return request(URL(string: urlString), method: method)
    }
}

public class MockNetwork: NetworkType {
    public init() {}
    public func request(_ urlRequest: URLRequest?) -> Request {
        return DiskRequest(urlRequest: urlRequest)
    }
    
    public func request(_ target: TargetType) -> Request {
        let url = URL(fileURLWithPath: target.diskPath ?? "")
        return request(url)
    }
}

public class Network: NSObject, NetworkType {
    // swiftlint:disable:next weak_delegate
    var sessionDelegate: NetworkSessionDelegate? = NetworkSessionDelegate()
    var urlSession: URLSession?
    var cacheProvider: CacheProvider
    let defaultParser: DecodableParserProtocol = DecodableJSONParser()

    deinit {
        print("bye network")
        urlSession?.invalidateAndCancel()
        sessionDelegate = nil
        urlSession = nil
    }

    public init(urlSessionConfiguration: URLSessionConfiguration = .default,
                cacheProvider: CacheProvider = NSCacheProvider()) {
        self.cacheProvider = cacheProvider
        self.urlSession = URLSession(configuration: urlSessionConfiguration,
                                     delegate: self.sessionDelegate, delegateQueue: nil)
    }

    public func request(_ urlRequest: URLRequest?) -> Request {
        let ourRequest = URLSessionDataRequest(urlSession: urlSession!,
                                               urlRequest: urlRequest,
                                               cacheProvider: cacheProvider,
                                               defaultParser: defaultParser)

        if let taskId = ourRequest.task?.taskIdentifier {
            sessionDelegate?.queue.async(flags: .barrier) {
                self.sessionDelegate?.requests[taskId] = ourRequest
            }
        }
        return ourRequest
    }
}

class NetworkSessionDelegate: NSObject, URLSessionDataDelegate {
    var requests = [TaskIdentifier: URLSessionDataRequest]()
    let queue: DispatchQueue = DispatchQueue(label: "no.shortcut.NetworkKit.Network",
                                             qos: .userInitiated,
                                             attributes: .concurrent)

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        queue.async(flags: .barrier) {
            if let request = self.requests[task.taskIdentifier] {
                request.urlSession(session, task: task, didCompleteWithError: error)
                self.requests[task.taskIdentifier] = nil
            }
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        queue.async(flags: .barrier) {
            if let request = self.requests[dataTask.taskIdentifier] {
                request.urlSession(session, dataTask: dataTask, didReceive: data)
            }
        }
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        queue.async(flags: .barrier) {
            if let request = self.requests[dataTask.taskIdentifier] {
                request.urlSession(session,
                                   dataTask: dataTask,
                                   didReceive: response,
                                   completionHandler: completionHandler)
            }
        }
    }
}
