/* Copyright (C) 2015-2016 Internet Systems Consortium, Inc. ("ISC")

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at http://mozilla.org/MPL/2.0/. */

%{ /* -*- C++ -*- */
#include <cerrno>
#include <climits>
#include <cstdlib>
#include <string>
#include <dhcp6/parser_context.h>
#include <asiolink/io_address.h>
#include <boost/lexical_cast.hpp>
#include <exceptions/exceptions.h>

// Work around an incompatibility in flex (at least versions
// 2.5.31 through 2.5.33): it generates code that does
// not conform to C89.  See Debian bug 333231
// <http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=333231>.
# undef yywrap
# define yywrap() 1

namespace {

bool start_token_flag = false;

isc::dhcp::Parser6Context::ParserType start_token_value;
unsigned int comment_start_line = 0;

};

// To avoid the call to exit... oops!
#define YY_FATAL_ERROR(msg) isc::dhcp::Parser6Context::fatal(msg)
%}

/* noyywrap disables automatic rewinding for the next file to parse. Since we
   always parse only a single string, there's no need to do any wraps. And
   using yywrap requires linking with -lfl, which provides the default yywrap
   implementation that always returns 1 anyway. */
%option noyywrap

/* nounput simplifies the lexer, by removing support for putting a character
   back into the input stream. We never use such capability anyway. */
%option nounput

/* batch means that we'll never use the generated lexer interactively. */
%option batch

/* avoid to get static global variables to remain with C++. */
/* in last resort %option reentrant */

/* Enables debug mode. To see the debug messages, one needs to also set
   yy_flex_debug to 1, then the debug messages will be printed on stderr. */
%option debug

/* I have no idea what this option does, except it was specified in the bison
   examples and Postgres folks added it to remove gcc 4.3 warnings. Let's
   be on the safe side and keep it. */
%option noinput

%x COMMENT
%x DIR_ENTER DIR_INCLUDE DIR_EXIT

/* These are not token expressions yet, just convenience expressions that
   can be used during actual token definitions. Note some can match
   incorrect inputs (e.g., IP addresses) which must be checked. */
int   \-?[0-9]+
blank [ \t]

UnicodeEscapeSequence           u[0-9A-Fa-f]{4}
JSONEscapeCharacter             ["\\/bfnrt]
JSONEscapeSequence              {JSONEscapeCharacter}|{UnicodeEscapeSequence}
JSONStandardCharacter           [^\x00-\x1f"\\]
JSONStringCharacter             {JSONStandardCharacter}|\\{JSONEscapeSequence}
JSONString                      \"{JSONStringCharacter}*\"

/* for errors */

BadUnicodeEscapeSequence        u[0-9A-Fa-f]{0,3}[^0-9A-Fa-f]
BadJSONEscapeSequence           [^"\\/bfnrtu]|{BadUnicodeEscapeSequence}
ControlCharacter                [\x00-\x1f]
ControlCharacterFill            [^"\\]|\\{JSONEscapeSequence}

%{
// This code run each time a pattern is matched. It updates the location
// by moving it ahead by yyleng bytes. yyleng specifies the length of the
// currently matched token.
#define YY_USER_ACTION  driver.loc_.columns(yyleng);
%}

%%

%{
    // This part of the code is copied over to the verbatim to the top
    // of the generated yylex function. Explanation:
    // http://www.gnu.org/software/bison/manual/html_node/Multiple-start_002dsymbols.html

    // Code run each time yylex is called.
    driver.loc_.step();

    if (start_token_flag) {
        start_token_flag = false;
        switch (start_token_value) {
        case Parser6Context::PARSER_GENERIC_JSON:
        default:
            return isc::dhcp::Dhcp6Parser::make_TOPLEVEL_GENERIC_JSON(driver.loc_);
        case Parser6Context::PARSER_DHCP6:
            return isc::dhcp::Dhcp6Parser::make_TOPLEVEL_DHCP6(driver.loc_);
        case Parser6Context::SUBPARSER_INTERFACES6:
            return isc::dhcp::Dhcp6Parser::make_SUB_INTERFACES6(driver.loc_);
        case Parser6Context::SUBPARSER_SUBNET6:
            return isc::dhcp::Dhcp6Parser::make_SUB_SUBNET6(driver.loc_);
        case Parser6Context::SUBPARSER_POOL6:
            return isc::dhcp::Dhcp6Parser::make_SUB_POOL6(driver.loc_);
        case Parser6Context::SUBPARSER_PD_POOL:
            return isc::dhcp::Dhcp6Parser::make_SUB_PD_POOL(driver.loc_);
        case Parser6Context::SUBPARSER_HOST_RESERVATION6:
            return isc::dhcp::Dhcp6Parser::make_SUB_RESERVATION(driver.loc_);
        case Parser6Context::SUBPARSER_OPTION_DATA:
            return isc::dhcp::Dhcp6Parser::make_SUB_OPTION_DATA(driver.loc_);
        case Parser6Context::SUBPARSER_HOOKS_LIBRARY:
            return isc::dhcp::Dhcp6Parser::make_SUB_HOOKS_LIBRARY(driver.loc_);
        case Parser6Context::SUBPARSER_JSON:
            return isc::dhcp::Dhcp6Parser::make_SUB_JSON(driver.loc_);
        }
    }
%}

#.* ;

"//"(.*) ;

"/*" {
  BEGIN(COMMENT);
  comment_start_line = driver.loc_.end.line;;
}

<COMMENT>"*/" BEGIN(INITIAL);
<COMMENT>. ;
<COMMENT><<EOF>> {
    isc_throw(Dhcp6ParseError, "Comment not closed. (/* in line " << comment_start_line);
}

"<?" BEGIN(DIR_ENTER);
<DIR_ENTER>"include" BEGIN(DIR_INCLUDE);
<DIR_INCLUDE>\"([^\"\n])+\" {
    // Include directive.

    // Extract the filename.
    std::string tmp(yytext+1);
    tmp.resize(tmp.size() - 1);

    driver.includeFile(tmp);
}
<DIR_ENTER,DIR_INCLUDE,DIR_EXIT><<EOF>> {
    isc_throw(Dhcp6ParseError, "Directive not closed.");
}
<DIR_EXIT>"?>" BEGIN(INITIAL);
    

<*>{blank}+   {
    // Ok, we found a with space. Let's ignore it and update loc variable.
    driver.loc_.step();
}

<*>[\n]+      {
    // Newline found. Let's update the location and continue.
    driver.loc_.lines(yyleng);
    driver.loc_.step();
}


\"Dhcp6\"  {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::CONFIG:
        return isc::dhcp::Dhcp6Parser::make_DHCP6(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("Dhcp6", driver.loc_);
    }
}

\"interfaces-config\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP6:
        return  isc::dhcp::Dhcp6Parser::make_INTERFACES_CONFIG(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("interfaces-config", driver.loc_);
    }
}

\"interfaces\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::INTERFACES_CONFIG:
        return  isc::dhcp::Dhcp6Parser::make_INTERFACES(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("interfaces", driver.loc_);
    }
}

\"lease-database\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP6:
        return isc::dhcp::Dhcp6Parser::make_LEASE_DATABASE(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("lease-database", driver.loc_);
    }
}

\"hosts-database\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP6:
        return isc::dhcp::Dhcp6Parser::make_HOSTS_DATABASE(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("hosts-database", driver.loc_);
    }
}

\"type\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::LEASE_DATABASE:
    case isc::dhcp::Parser6Context::HOSTS_DATABASE:
    case isc::dhcp::Parser6Context::SERVER_ID:
        return isc::dhcp::Dhcp6Parser::make_TYPE(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("type", driver.loc_);
    }
}

\"user\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::LEASE_DATABASE:
    case isc::dhcp::Parser6Context::HOSTS_DATABASE:
        return isc::dhcp::Dhcp6Parser::make_USER(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("user", driver.loc_);
    }
}

\"password\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::LEASE_DATABASE:
    case isc::dhcp::Parser6Context::HOSTS_DATABASE:
        return isc::dhcp::Dhcp6Parser::make_PASSWORD(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("password", driver.loc_);
    }
}

\"host\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::LEASE_DATABASE:
    case isc::dhcp::Parser6Context::HOSTS_DATABASE:
        return isc::dhcp::Dhcp6Parser::make_HOST(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("host", driver.loc_);
    }
}

\"persist\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::LEASE_DATABASE:
    case isc::dhcp::Parser6Context::HOSTS_DATABASE:
    case isc::dhcp::Parser6Context::SERVER_ID:
        return isc::dhcp::Dhcp6Parser::make_PERSIST(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("persist", driver.loc_);
    }
}

\"lfc-interval\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::LEASE_DATABASE:
    case isc::dhcp::Parser6Context::HOSTS_DATABASE:
        return isc::dhcp::Dhcp6Parser::make_LFC_INTERVAL(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("lfc-interval", driver.loc_);
    }
}

\"preferred-lifetime\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP6:
        return isc::dhcp::Dhcp6Parser::make_PREFERRED_LIFETIME(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("preferred-lifetime", driver.loc_);
    }
}

\"valid-lifetime\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP6:
        return isc::dhcp::Dhcp6Parser::make_VALID_LIFETIME(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("valid-lifetime", driver.loc_);
    }
}

\"renew-timer\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP6:
        return isc::dhcp::Dhcp6Parser::make_RENEW_TIMER(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("renew-timer", driver.loc_);
    }
}

\"rebind-timer\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP6:
        return isc::dhcp::Dhcp6Parser::make_REBIND_TIMER(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("rebind-timer", driver.loc_);
    }
}

\"subnet6\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP6:
        return isc::dhcp::Dhcp6Parser::make_SUBNET6(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("subnet6", driver.loc_);
    }
}

\"option-data\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP6:
    case isc::dhcp::Parser6Context::SUBNET6:
    case isc::dhcp::Parser6Context::POOLS:
    case isc::dhcp::Parser6Context::PD_POOLS:
    case isc::dhcp::Parser6Context::RESERVATIONS:
    case isc::dhcp::Parser6Context::CLIENT_CLASSES:
    case isc::dhcp::Parser6Context::CLIENT_CLASS:
        return isc::dhcp::Dhcp6Parser::make_OPTION_DATA(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("option-data", driver.loc_);
    }
}

\"name\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::LEASE_DATABASE:
    case isc::dhcp::Parser6Context::HOSTS_DATABASE:
    case isc::dhcp::Parser6Context::OPTION_DATA:
    case isc::dhcp::Parser6Context::CLIENT_CLASSES:
    case isc::dhcp::Parser6Context::CLIENT_CLASS:
    case isc::dhcp::Parser6Context::LOGGERS:
        return isc::dhcp::Dhcp6Parser::make_NAME(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("name", driver.loc_);
    }
}

\"data\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::OPTION_DATA:
        return isc::dhcp::Dhcp6Parser::make_DATA(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("data", driver.loc_);
    }
}

\"pools\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::SUBNET6:
        return isc::dhcp::Dhcp6Parser::make_POOLS(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("pools", driver.loc_);
    }
}

\"pd-pools\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::SUBNET6:
        return isc::dhcp::Dhcp6Parser::make_PD_POOLS(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("pd-pools", driver.loc_);
    }
}

\"prefix\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::PD_POOLS:
        return isc::dhcp::Dhcp6Parser::make_PREFIX(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("prefix", driver.loc_);
    }
}

\"prefix-len\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::PD_POOLS:
        return isc::dhcp::Dhcp6Parser::make_PREFIX_LEN(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("prefix-len", driver.loc_);
    }
}

\"delegated-len\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::PD_POOLS:
        return isc::dhcp::Dhcp6Parser::make_DELEGATED_LEN(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("delegated-len", driver.loc_);
    }
}

\"pool\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::POOLS:
        return isc::dhcp::Dhcp6Parser::make_POOL(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("pool", driver.loc_);
    }
}

\"subnet\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::SUBNET6:
        return isc::dhcp::Dhcp6Parser::make_SUBNET(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("subnet", driver.loc_);
    }
}

\"interface\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::SUBNET6:
        return isc::dhcp::Dhcp6Parser::make_INTERFACE(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("interface", driver.loc_);
    }
}

\"id\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::SUBNET6:
        return isc::dhcp::Dhcp6Parser::make_ID(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("id", driver.loc_);
    }
}

\"code\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::OPTION_DATA:
        return isc::dhcp::Dhcp6Parser::make_CODE(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("code", driver.loc_);
    }
}

\"mac-sources\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP6:
        return isc::dhcp::Dhcp6Parser::make_MAC_SOURCES(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("mac-sources", driver.loc_);
    }
}

\"relay-supplied-options\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP6:
        return isc::dhcp::Dhcp6Parser::make_RELAY_SUPPLIED_OPTIONS(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("relay-supplied-options", driver.loc_);
    }
}

\"host-reservation-identifiers\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP6:
        return isc::dhcp::Dhcp6Parser::make_HOST_RESERVATION_IDENTIFIERS(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("host-reservation-identifiers", driver.loc_);
    }
}

\"Logging\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::CONFIG:
        return isc::dhcp::Dhcp6Parser::make_LOGGING(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("Logging", driver.loc_);
    }
}

\"loggers\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::LOGGING:
        return isc::dhcp::Dhcp6Parser::make_LOGGERS(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("loggers", driver.loc_);
    }
}

\"output_options\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::LOGGERS:
        return isc::dhcp::Dhcp6Parser::make_OUTPUT_OPTIONS(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("output_options", driver.loc_);
    }
}

\"output\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::OUTPUT_OPTIONS:
        return isc::dhcp::Dhcp6Parser::make_OUTPUT(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("output", driver.loc_);
    }
}

\"debuglevel\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::LOGGERS:
        return isc::dhcp::Dhcp6Parser::make_DEBUGLEVEL(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("debuglevel", driver.loc_);
    }
}

\"severity\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::LOGGERS:
        return isc::dhcp::Dhcp6Parser::make_SEVERITY(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("severity", driver.loc_);
    }
}

\"client-classes\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP6:
    case isc::dhcp::Parser6Context::RESERVATIONS:
        return isc::dhcp::Dhcp6Parser::make_CLIENT_CLASSES(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("client-classes", driver.loc_);
    }
}

\"client-class\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::SUBNET6:
    case isc::dhcp::Parser6Context::CLIENT_CLASSES:
        return isc::dhcp::Dhcp6Parser::make_CLIENT_CLASS(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("client-class", driver.loc_);
    }
}

\"test\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::CLIENT_CLASSES:
    case isc::dhcp::Parser6Context::CLIENT_CLASS:
        return isc::dhcp::Dhcp6Parser::make_TEST(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("test", driver.loc_);
    }
}

\"reservations\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::SUBNET6:
        return isc::dhcp::Dhcp6Parser::make_RESERVATIONS(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("reservations", driver.loc_);
    }
}

\"ip-addresses\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::RESERVATIONS:
        return isc::dhcp::Dhcp6Parser::make_IP_ADDRESSES(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("ip-addresses", driver.loc_);
    }
}

\"prefixes\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::RESERVATIONS:
        return isc::dhcp::Dhcp6Parser::make_PREFIXES(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("prefixes", driver.loc_);
    }
}

\"duid\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::MAC_SOURCES:
    case isc::dhcp::Parser6Context::HOST_RESERVATION_IDENTIFIERS:
    case isc::dhcp::Parser6Context::RESERVATIONS:
        return isc::dhcp::Dhcp6Parser::make_DUID(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("duid", driver.loc_);
    }
}

\"hw-address\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::HOST_RESERVATION_IDENTIFIERS:
    case isc::dhcp::Parser6Context::RESERVATIONS:
        return isc::dhcp::Dhcp6Parser::make_HW_ADDRESS(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("hw-address", driver.loc_);
    }
}

\"hostname\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::RESERVATIONS:
        return isc::dhcp::Dhcp6Parser::make_HOSTNAME(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("hostname", driver.loc_);
    }
}

\"space\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::OPTION_DATA:
        return isc::dhcp::Dhcp6Parser::make_SPACE(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("space", driver.loc_);
    }
}

\"csv-format\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::OPTION_DATA:
        return isc::dhcp::Dhcp6Parser::make_CSV_FORMAT(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("csv-format", driver.loc_);
    }
}

\"hooks-libraries\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP6:
        return isc::dhcp::Dhcp6Parser::make_HOOKS_LIBRARIES(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("hooks-libraries", driver.loc_);
    }
}

\"library\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::HOOKS_LIBRARIES:
        return isc::dhcp::Dhcp6Parser::make_LIBRARY(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("library", driver.loc_);
    }
}

\"server-id\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP6:
        return isc::dhcp::Dhcp6Parser::make_SERVER_ID(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("server-id", driver.loc_);
    }
}

\"identifier\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::SERVER_ID:
        return isc::dhcp::Dhcp6Parser::make_IDENTIFIER(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("identifier", driver.loc_);
    }
}

\"htype\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::SERVER_ID:
        return isc::dhcp::Dhcp6Parser::make_HTYPE(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("htype", driver.loc_);
    }
}

\"time\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::SERVER_ID:
        return isc::dhcp::Dhcp6Parser::make_TIME(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("time", driver.loc_);
    }
}

\"enterprise-id\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::SERVER_ID:
        return isc::dhcp::Dhcp6Parser::make_ENTERPRISE_ID(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("enterprise-id", driver.loc_);
    }
}

\"expired-leases-processing\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP6:
        return isc::dhcp::Dhcp6Parser::make_EXPIRED_LEASES_PROCESSING(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("expired-leases-processing", driver.loc_);
    }
}

\"dhcp4o6-port\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP6:
        return isc::dhcp::Dhcp6Parser::make_DHCP4O6_PORT(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("dhcp4o6-port", driver.loc_);
    }
}

\"dhcp-ddns\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP6:
        return isc::dhcp::Dhcp6Parser::make_DHCP_DDNS(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("dhcp-ddns", driver.loc_);
    }
}

\"enable-updates\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP_DDNS:
        return isc::dhcp::Dhcp6Parser::make_ENABLE_UPDATES(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("enable-updates", driver.loc_);
    }
}

\"qualifying-suffix\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::DHCP_DDNS:
        return isc::dhcp::Dhcp6Parser::make_QUALIFYING_SUFFIX(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("qualifying-suffix", driver.loc_);
    }
}

\"Dhcp4\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::CONFIG:
        return isc::dhcp::Dhcp6Parser::make_DHCP4(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("Dhcp4", driver.loc_);
    }
}

\"DhcpDdns\" {
    switch(driver.ctx_) {
    case isc::dhcp::Parser6Context::CONFIG:
        return isc::dhcp::Dhcp6Parser::make_DHCPDDNS(driver.loc_);
    default:
        return isc::dhcp::Dhcp6Parser::make_STRING("DhcpDdns", driver.loc_);
    }
}

{JSONString} {
    // A string has been matched. It contains the actual string and single quotes.
    // We need to get those quotes out of the way and just use its content, e.g.
    // for 'foo' we should get foo
    std::string raw(yytext+1);
    size_t len = raw.size() - 1;
    raw.resize(len);
    std::string decoded;
    decoded.reserve(len);
    for (size_t pos = 0; pos < len; ++pos) {
        char c = raw[pos];
        switch (c) {
        case '"':
            // impossible condition
            driver.error(driver.loc_, "Bad quote in \"" + raw + "\"");
        case '\\':
            ++pos;
            if (pos >= len) {
                // impossible condition
                driver.error(driver.loc_, "Overflow escape in \"" + raw + "\"");
            }
            c = raw[pos];
            switch (c) {
            case '"':
            case '\\':
            case '/':
                decoded.push_back(c);
                break;
            case 'b':
                decoded.push_back('\b');
                break;
            case 'f':
                decoded.push_back('\f');
                break;
            case 'n':
                decoded.push_back('\n');
                break;
            case 'r':
                decoded.push_back('\r');
                break;
            case 't':
                decoded.push_back('\t');
                break;
            case 'u':
                // not yet implemented
                driver.error(driver.loc_, "Unsupported unicode escape in \"" + raw + "\"");
            default:
                // impossible condition
                driver.error(driver.loc_, "Bad escape in \"" + raw + "\"");
            }
            break;
        default:
            if (c < 0x20) {
                // impossible condition
                driver.error(driver.loc_, "Invalid control in \"" + raw + "\"");
            }
            decoded.push_back(c);
        }
    }

    return isc::dhcp::Dhcp6Parser::make_STRING(decoded, driver.loc_);
}

\"{JSONStringCharacter}*{ControlCharacter}{ControlCharacterFill}*\" {
    // Bad string with a forbidden control character inside
    driver.error(driver.loc_, "Invalid control in " + std::string(yytext));
}

\"{JSONStringCharacter}*\\{BadJSONEscapeSequence}[^\x00-\x1f"]*\" {
    // Bad string with a bad escape inside
    driver.error(driver.loc_, "Bad escape in " + std::string(yytext));
}
    
\"{JSONStringCharacter}*\\\" {
    // Bad string with an open escape at the end
    driver.error(driver.loc_, "Overflow escape in " + std::string(yytext));
}

"["    { return isc::dhcp::Dhcp6Parser::make_LSQUARE_BRACKET(driver.loc_); }
"]"    { return isc::dhcp::Dhcp6Parser::make_RSQUARE_BRACKET(driver.loc_); }
"{"    { return isc::dhcp::Dhcp6Parser::make_LCURLY_BRACKET(driver.loc_); }
"}"    { return isc::dhcp::Dhcp6Parser::make_RCURLY_BRACKET(driver.loc_); }
","    { return isc::dhcp::Dhcp6Parser::make_COMMA(driver.loc_); }
":"    { return isc::dhcp::Dhcp6Parser::make_COLON(driver.loc_); }

{int} {
    // An integer was found.
    std::string tmp(yytext);
    int64_t integer = 0;
    try {
        // In substring we want to use negative values (e.g. -1).
        // In enterprise-id we need to use values up to 0xffffffff.
        // To cover both of those use cases, we need at least
        // int64_t.
        integer = boost::lexical_cast<int64_t>(tmp);
    } catch (const boost::bad_lexical_cast &) {
        driver.error(driver.loc_, "Failed to convert " + tmp + " to an integer.");
    }

    // The parser needs the string form as double conversion is no lossless
    return isc::dhcp::Dhcp6Parser::make_INTEGER(integer, driver.loc_);
}

[-+]?[0-9]*\.?[0-9]*([eE][-+]?[0-9]+)? {
    // A floating point was found.
    std::string tmp(yytext);
    double fp = 0.0;
    try {
        fp = boost::lexical_cast<double>(tmp);
    } catch (const boost::bad_lexical_cast &) {
        driver.error(driver.loc_, "Failed to convert " + tmp + " to a floating point.");
    }

    return isc::dhcp::Dhcp6Parser::make_FLOAT(fp, driver.loc_);
}

true|false {
    string tmp(yytext);
    return isc::dhcp::Dhcp6Parser::make_BOOLEAN(tmp == "true", driver.loc_);
}

null {
   return isc::dhcp::Dhcp6Parser::make_NULL_TYPE(driver.loc_);
}

<*>.   driver.error (driver.loc_, "Invalid character: " + std::string(yytext));

<<EOF>> {
    if (driver.states_.empty()) {
        return isc::dhcp::Dhcp6Parser::make_END(driver.loc_);
    }
    driver.loc_ = driver.locs_.back();
    driver.locs_.pop_back();
    driver.file_ = driver.files_.back();
    driver.files_.pop_back();
    if (driver.sfile_) {
        fclose(driver.sfile_);
        driver.sfile_ = 0;
    }
    if (!driver.sfiles_.empty()) {
        driver.sfile_ = driver.sfiles_.back();
        driver.sfiles_.pop_back();
    }
    parser6__delete_buffer(YY_CURRENT_BUFFER);
    parser6__switch_to_buffer(driver.states_.back());
    driver.states_.pop_back();

    BEGIN(DIR_EXIT);
}

%%

using namespace isc::dhcp;

void
Parser6Context::scanStringBegin(const std::string& str, ParserType parser_type)
{
    start_token_flag = true;
    start_token_value = parser_type;

    file_ = "<string>";
    sfile_ = 0;
    loc_.initialize(&file_);
    yy_flex_debug = trace_scanning_;
    YY_BUFFER_STATE buffer;
    buffer = yy_scan_bytes(str.c_str(), str.size());
    if (!buffer) {
        fatal("cannot scan string");
        // fatal() throws an exception so this can't be reached
    }
}

void
Parser6Context::scanFileBegin(FILE * f,
                              const std::string& filename,
                              ParserType parser_type)
{
    start_token_flag = true;
    start_token_value = parser_type;

    file_ = filename;
    sfile_ = f;
    loc_.initialize(&file_);
    yy_flex_debug = trace_scanning_;
    YY_BUFFER_STATE buffer;

    // See dhcp6_lexer.cc header for available definitions
    buffer = parser6__create_buffer(f, 65536 /*buffer size*/);
    if (!buffer) {
        fatal("cannot scan file " + filename);
    }
    parser6__switch_to_buffer(buffer);
}

void
Parser6Context::scanEnd() {
    if (sfile_)
        fclose(sfile_);
    sfile_ = 0;
    static_cast<void>(parser6_lex_destroy());
    // Close files
    while (!sfiles_.empty()) {
        FILE* f = sfiles_.back();
        if (f) {
            fclose(f);
        }
        sfiles_.pop_back();
    }
    // Delete states
    while (!states_.empty()) {
        parser6__delete_buffer(states_.back());
        states_.pop_back();
    }
}

void
Parser6Context::includeFile(const std::string& filename) {
    if (states_.size() > 10) {
        fatal("Too many nested include.");
    }

    FILE* f = fopen(filename.c_str(), "r");
    if (!f) {
        fatal("Can't open include file " + filename);
    }
    if (sfile_) {
        sfiles_.push_back(sfile_);
    }
    sfile_ = f;
    states_.push_back(YY_CURRENT_BUFFER);
    YY_BUFFER_STATE buffer;
    buffer = parser6__create_buffer(f, 65536 /*buffer size*/);
    if (!buffer) {
        fatal( "Can't scan include file " + filename);
    }
    parser6__switch_to_buffer(buffer);
    files_.push_back(file_);
    file_ = filename;
    locs_.push_back(loc_);
    loc_.initialize(&file_);

    BEGIN(INITIAL);
}

namespace {
/// To avoid unused function error
class Dummy {
    // cppcheck-suppress unusedPrivateFunction
    void dummy() { yy_fatal_error("Fix me: how to disable its definition?"); }
};
}
