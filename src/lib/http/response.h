// Copyright (C) 2016 Internet Systems Consortium, Inc. ("ISC")
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#ifndef HTTP_RESPONSE_H
#define HTTP_RESPONSE_H

#include <exceptions/exceptions.h>
#include <http/http_types.h>
#include <boost/lexical_cast.hpp>
#include <boost/shared_ptr.hpp>
#include <cstdint>
#include <map>
#include <string>

namespace isc {
namespace http {

/// @brief Generic exception thrown by @ref HttpResponse class.
class HttpResponseError : public Exception {
public:
    HttpResponseError(const char* file, size_t line, const char* what) :
        isc::Exception(file, line, what) { };
};

enum class HttpStatusCode : std::uint16_t {
    OK = 200,
    CREATED = 201,
    ACCEPTED = 202,
    NO_CONTENT = 203,
    MULTIPLE_CHOICES = 300,
    MOVED_PERMANENTLY = 301,
    MOVED_TEMPORARILY = 302,
    NOT_MODIFIED = 304,
    BAD_REQUEST = 400,
    UNAUTHORIZED = 401,
    FORBIDDEN = 403,
    NOT_FOUND = 404,
    INTERNAL_SERVER_ERROR = 500,
    NOT_IMPLEMENTED = 501,
    BAD_GATEWAY = 502,
    SERVICE_UNAVAILABLE = 503
};

class HttpResponse;

/// @brief Pointer to the @ref HttpResponse object.
typedef boost::shared_ptr<HttpResponse> HttpResponsePtr;

/// @brief Pointer to the const @ref HttpResponse object.
typedef boost::shared_ptr<const HttpResponse> ConstHttpResponsePtr;

class HttpResponse {
public:

    HttpResponse(const HttpVersion& version, const HttpStatusCode& status_code);

    virtual ~HttpResponse() { }

    void addHeader(const std::string& name, const std::string& value) {
        headers_[name] = value;
    }

    virtual void setBody(const std::string& body);

    static bool isClientError(const HttpStatusCode& status_code);

    static bool isServerError(const HttpStatusCode& status_code);

    static std::string statusCodeToString(const HttpStatusCode& status_code);

    std::string toString() const;

protected:

    virtual std::string getDateHeaderValue() const;

    static uint16_t statusCodeToNumber(const HttpStatusCode& status_code);

private:

    void setGenericBody(const HttpStatusCode& status_code) { };

    HttpVersion http_version_;

    HttpStatusCode status_code_;

    std::map<std::string, std::string> headers_;

    std::string body_;

};

} // namespace http
} // namespace isc

#endif
