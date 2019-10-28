// https://justsitandgrin.net/swift-package-manager/ios/2019/01/20/swift_package_manager_vs_ios.html

@testable import NetworkKit
import XCTest

struct HTTPBinResult: Decodable {
    let url: String
    let form: [String: String]?
    let args: [String: String]?
    let json: [String: String]?
}

struct HTTPBinArrayResult: Decodable {
    let url: String
    let form: [String: String]?
    let args: [String: [String]]?
    let json: [String: String]?
}

final class NetworkKitTests: XCTestCase {
    private var webService = Webservice(baseURL: URL(string: "https://httpbin.org/")!)

    func testGetRequestResponse() {
        let expectation = XCTestExpectation(description: "make get request")

        webService.request(withPath: "get", method: .get) { (response: Response<HTTPBinResult>) in

            XCTAssertTrue(Thread.isMainThread)

            switch response.result {
            case let .success(httpBinResult):
                XCTAssertEqual((response.response as? HTTPURLResponse)?.statusCode, 200)
                XCTAssertEqual(httpBinResult.url, "https://httpbin.org/get")
            case let .failure(error):
                XCTFail()
                print("error: \(error)")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3)
    }

    func testGetDataRequestResponse() {
        let expectation = XCTestExpectation(description: "make get request")

        webService.requestData(withPath: "get", method: .get) { (_, response, result: Result<Data, NetworkStackError>) in

            XCTAssertTrue(Thread.isMainThread)

            switch result {
            case let .success(data):
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
                XCTAssertNotNil(data)
            case let .failure(error):
                XCTFail()
                print("error: \(error)")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3)
    }

    func testPostRequest() {
        let expectation = XCTestExpectation(description: "make post request")

        let parameters = ["test": "Hello world",
                          "message": "øåæ",
                          "face": "🤓"]

        webService.request(withPath: "post", method: .post, bodyType: .formEncoded(parameters: parameters)) { (response: Response<HTTPBinResult>) in

            XCTAssertTrue(Thread.isMainThread)

            switch response.result {
            case let .success(httpBinResult):
                XCTAssertEqual((response.response as? HTTPURLResponse)?.statusCode, 200)
                XCTAssertEqual(httpBinResult.url, "https://httpbin.org/post")
                XCTAssertEqual(httpBinResult.form, parameters)
            case let .failure(error):
                XCTFail()
                print("error: \(error)")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3)
    }

    func testPostJSONRequest() {
        let expectation = XCTestExpectation(description: "make post request")

        let parameters = ["test": "Hello world",
                          "message": "øåæ",
                          "face": "🤓"]

        webService.request(withPath: "post", method: .post, bodyType: .json, body: parameters) { (response: Response<HTTPBinResult>) in

            XCTAssertTrue(Thread.isMainThread)

            switch response.result {
            case let .success(httpBinResult):
                XCTAssertEqual((response.response as? HTTPURLResponse)?.statusCode, 200)
                XCTAssertEqual(httpBinResult.url, "https://httpbin.org/post")
                XCTAssertEqual(httpBinResult.json, parameters)
            case let .failure(error):
                XCTFail()
                print("error: \(error)")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3)
    }

    func testGetRequestQueryParamsResponse() {
        let expectation = XCTestExpectation(description: "make get request with query parameters")

        let parameters = ["test": "Hello world",
                          "message": "cool",
                          "number": "23"]

        webService.request(withPath: "get", method: .get, queryParameters: QueryParameters(parameters)) { (response: Response<HTTPBinResult>) in

            XCTAssertTrue(Thread.isMainThread)

            switch response.result {
            case let .success(httpBinResult):
                XCTAssertEqual((response.response as? HTTPURLResponse)?.statusCode, 200)
                XCTAssertEqual(httpBinResult.args, parameters)

            case let .failure(error):
                XCTFail()
                print("error: \(error)")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3)
    }

    func testGet404Response() {
        let expectation = XCTestExpectation(description: "get a 404 status code")

        webService.request(withPath: "status/404", method: .get) { (response: Response<HTTPBinResult>) in

            XCTAssertTrue(Thread.isMainThread)

            switch response.result {
            case .success:
                XCTFail()
            case .failure:
                XCTAssertNotNil(response.data)
                XCTAssertEqual((response.response as? HTTPURLResponse)?.statusCode, 404)
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3)
    }

    func testCancelRequest() {
        let expectation = XCTestExpectation(description: "cancel a request")

        let taskId = webService.request(withPath: "delay/5", method: .get) { (response: Response<HTTPBinResult>) in
            switch response.result {
            case .success:
                XCTFail("the request should fail")
            case let .failure(error):
                XCTAssertNil(response.data)

                guard case let .responseError(responseError) = error else {
                    XCTFail("there should be an error")
                    return
                }

                XCTAssertEqual((responseError as NSError).code, NSURLErrorCancelled)
            }

            expectation.fulfill()
        }

        webService.cancelTask(with: taskId!)
        
        wait(for: [expectation], timeout: 5)
    }
}
