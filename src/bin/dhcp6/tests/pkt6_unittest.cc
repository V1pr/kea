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

#include <config.h>
#include <iostream>
#include <sstream>

#include <arpa/inet.h>
#include <gtest/gtest.h>


#include "dhcp6/pkt6.h"

using namespace std;
using namespace isc;

// empty class for now, but may be extended once Addr6 becomes bigger
class Pkt6Test : public ::testing::Test {
public:
    Pkt6Test() {
    }
};

TEST_F(Pkt6Test, constructor) {
    Pkt6 * pkt1 = new Pkt6(17);
    
    ASSERT_EQ(pkt1->dataLen_, 17);

    char * buf = new char[23];
    // can't use char buf[23], as Pkt6 takes ownership of the data

    Pkt6 * pkt2 = new Pkt6(buf, 23);

    ASSERT_EQ(pkt2->dataLen_, 23);
    ASSERT_EQ(pkt2->data_, buf);

    delete pkt1;
    delete pkt2;
}

