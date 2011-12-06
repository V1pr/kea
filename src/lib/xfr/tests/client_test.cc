// Copyright (C) 2011  Internet Systems Consortium, Inc. ("ISC")
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND ISC DISCLAIMS ALL WARRANTIES WITH
// REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
// AND FITNESS.  IN NO EVENT SHALL ISC BE LIABLE FOR ANY SPECIAL, DIRECT,
// INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
// LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
// OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
// PERFORMANCE OF THIS SOFTWARE.

#include <gtest/gtest.h>

#include <sys/un.h>
#include <string>

#include <xfr/xfrout_client.h>

using namespace std;
using namespace isc::xfr;

namespace {

TEST(ClientTest, connetFile) {
    // File path is too long
    const struct sockaddr_un sun;
    EXPECT_THROW(XfroutClient(string(sizeof(sun.sun_path), 'x')).connect(),
                 XfroutError);

    // File doesn't exist (we assume the file "no_such_file" doesn't exist)
    EXPECT_THROW(XfroutClient("no_such_file").connect(), XfroutError);
}

}
