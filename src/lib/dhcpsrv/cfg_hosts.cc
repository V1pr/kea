// Copyright (C) 2014 Internet Systems Consortium, Inc. ("ISC")
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

#include <dhcpsrv/cfg_hosts.h>
#include <exceptions/exceptions.h>
#include <ostream>

using namespace isc::asiolink;

namespace isc {
namespace dhcp {

ConstHostCollection
CfgHosts::getAll(const HWAddrPtr& hwaddr, const DuidPtr& duid) const {
    ConstHostCollection collection;
    getAllInternal<ConstHostCollection>(hwaddr, duid, collection);
    return (collection);
}

HostCollection
CfgHosts::getAll(const HWAddrPtr& hwaddr, const DuidPtr& duid) {
    HostCollection collection;
    getAllInternal<HostCollection>(hwaddr, duid, collection);
    return (collection);
}

ConstHostCollection
CfgHosts::getAll4(const IOAddress& address) const {
    ConstHostCollection collection;
    getAllInternal4<ConstHostCollection>(address, collection);
    return (collection);
}

HostCollection
CfgHosts::getAll4(const IOAddress& address) {
    HostCollection collection;
    getAllInternal4<HostCollection>(address, collection);
    return (collection);
}

ConstHostCollection
CfgHosts::getAll6(const IOAddress& address) const {
    ConstHostCollection collection;
    getAllInternal6<ConstHostCollection>(address, collection);
    return (collection);
}

HostCollection
CfgHosts::getAll6(const IOAddress& address) {
    HostCollection collection;
    getAllInternal6<HostCollection>(address, collection);
    return (collection);
}

template<typename Storage>
void
CfgHosts::getAllInternal(const std::vector<uint8_t>& identifier,
                         const Host::IdentifierType& identifier_type,
                         Storage& storage) const {
    // Use the identifier and identifier type as a composite key.
    const HostContainerIndex0& idx = hosts_.get<0>();
    boost::tuple<const std::vector<uint8_t>, const Host::IdentifierType> t =
        boost::make_tuple(identifier, identifier_type);

    // Append each Host object to the storage.
    for (HostContainerIndex0::iterator host = idx.lower_bound(t); host != idx.upper_bound(t);
         ++host) {
        storage.push_back(*host);
    }
}

template<typename Storage>
void
CfgHosts::getAllInternal(const HWAddrPtr& hwaddr, const DuidPtr& duid,
                         Storage& storage) const {
    // Get hosts using HW address.
    if (hwaddr) {
        getAllInternal<Storage>(hwaddr->hwaddr_, Host::IDENT_HWADDR, storage);
    }
    // Get hosts using DUID.
    if (duid) {
        getAllInternal<Storage>(duid->getDuid(), Host::IDENT_DUID, storage);
    }
}

template<typename Storage>
void
CfgHosts::getAllInternal4(const IOAddress& address, Storage& storage) const {
    // Must not specify address other than IPv4.
    if (!address.isV4()) {
        isc_throw(BadHostAddress, "must specify an IPv4 address when searching"
                  " for a host, specified address was " << address);
    }
    // Search for the Host using the reserved IPv4 address as a key.
    const HostContainerIndex1& idx = hosts_.get<1>();
    HostContainerIndex1Range r = idx.equal_range(address);
    // Append each Host object to the storage.
    for (HostContainerIndex1::iterator host = r.first; host != r.second;
         ++host) {
        storage.push_back(*host);
    }
}

template<typename Storage>
void
CfgHosts::getAllInternal6(const IOAddress& address, Storage& storage) const {
    // Must not specify address other than IPv6.
    if (!address.isV6()) {
        isc_throw(BadHostAddress, "must specify an IPv6 address when searching"
                  " for a host, specified address was " << address);
    }
    // Search for the Host using the reserved IPv4 address as a key.
    const HostContainerIndex1& idx = hosts_.get<1>();
    HostContainerIndex1Range r = idx.equal_range(address);
    // Append each Host object to the storage.
    for (HostContainerIndex1::iterator host = r.first; host != r.second;
         ++host) {
        storage.push_back(*host);
    }
}


ConstHostPtr
CfgHosts::get4(const SubnetID& subnet_id, const HWAddrPtr& hwaddr,
               const DuidPtr& duid) const {
    // The false value indicates that it is an IPv4 subnet.
    return (getHostInternal(subnet_id, false, hwaddr, duid));
}

HostPtr
CfgHosts::get4(const SubnetID& subnet_id, const HWAddrPtr& hwaddr,
               const DuidPtr& duid) {
    // The false value indicates that it is an IPv4 subnet.
    return (getHostInternal(subnet_id, false, hwaddr, duid));
}

ConstHostPtr
CfgHosts::get4(const SubnetID& subnet_id, const IOAddress& address) const {
    ConstHostCollection hosts = getAll4(address);
    for (ConstHostCollection::const_iterator host = hosts.begin();
         host != hosts.end(); ++host) {
        if ((*host)->getIPv4SubnetID() == subnet_id) {
            return (*host);
        }
    }
    return (ConstHostPtr());
}


ConstHostPtr
CfgHosts::get6(const SubnetID& subnet_id, const DuidPtr& duid,
               const HWAddrPtr& hwaddr) const {
    // The true value indicates that it is an IPv6 subnet.
    return (getHostInternal(subnet_id, true, hwaddr, duid));
}

HostPtr
CfgHosts::get6(const SubnetID& subnet_id, const DuidPtr& duid,
               const HWAddrPtr& hwaddr) {
    // The true value indicates that it is an IPv6 subnet.
    return (getHostInternal(subnet_id, true, hwaddr, duid));
}

ConstHostPtr
CfgHosts::get6(const IOAddress&, const uint8_t) const {
    isc_throw(isc::NotImplemented,
              "get6(prefix, len) const is not implemented");
}

HostPtr
CfgHosts::get6(const IOAddress&, const uint8_t) {
    isc_throw(isc::NotImplemented, "get6(prefix, len) is not implemented");
}

ConstHostPtr
CfgHosts::get6(const SubnetID& subnet_id, const IOAddress& address) const {
    ConstHostCollection hosts = getAll6(address);
    for (ConstHostCollection::const_iterator host = hosts.begin();
         host != hosts.end(); ++host) {
        if ((*host)->getIPv4SubnetID() == subnet_id) {
            return (*host);
        }
    }
    return (ConstHostPtr());
}


HostPtr
CfgHosts::getHostInternal(const SubnetID& subnet_id, const bool subnet6,
                          const HWAddrPtr& hwaddr, const DuidPtr& duid) const {
    // Get all hosts for the HW address and DUID. This may return multiple hosts
    // for different subnets, but the number of hosts returned should be low
    // because one host presumably doesn't show up in many subnets.
    HostCollection hosts;
    getAllInternal<HostCollection>(hwaddr, duid, hosts);

    HostPtr host;
    // Iterate over the returned hosts and select those for which the
    // subnet id matches.
    for (HostCollection::const_iterator host_it = hosts.begin();
         host_it != hosts.end(); ++host_it) {
        // Check if this is IPv4 subnet or IPv6 subnet.
        SubnetID host_subnet_id = subnet6 ? (*host_it)->getIPv6SubnetID() :
            (*host_it)->getIPv4SubnetID();

        if (subnet_id == host_subnet_id) {
            // If this is the first occurrence of the host for this subnet,
            // remember it. But, if we find that this is second @c Host object
            // for the same client, it is a misconfiguration. Most likely,
            // the administrator has specified one reservation for a HW
            // address and another one for the DUID, which gives an ambiguous
            // result, and we don't know which reservation we should choose.
            // Therefore, throw an exception.
            if (!host) {
                host = *host_it;

            } else {
                isc_throw(DuplicateHost,  "more than one reservation found"
                          " for the host belonging to the subnet with id '"
                          << subnet_id << "' and using the HW address '"
                          << (hwaddr ? hwaddr->toText(false) : "(null)")
                          << "' and DUID '"
                          << (duid ? duid->toText() : "(null)")
                          << "'");
            }
        }
    }
    return (host);
}


void
CfgHosts::add(const HostPtr& host) {
    // Sanity check that the host is non-null.
    if (!host) {
        isc_throw(BadValue, "specified host object must not be NULL when it"
                  " is added to the configuration");
    }
    // At least one subnet ID must be non-zero
    if (host->getIPv4SubnetID() == 0 && host->getIPv6SubnetID() == 0) {
        isc_throw(BadValue, "must not use both IPv4 and IPv6 subnet ids of"
                  " 0 when adding new host reservation");
    }

    if (host->getIPv4SubnetID() != 0) {
        add4(host);
    }

    if (host->getIPv6SubnetID() != 0) {
        add6(host);
    }
}

void
CfgHosts::add4(const HostPtr& host) {

    /// @todo This may need further sanity checks.
    HWAddrPtr hwaddr = host->getHWAddress();
    DuidPtr duid = host->getDuid();

    // There should be at least one resource reserved: hostname, IPv4
    // address, IPv6 address or prefix.
    if (host->getHostname().empty() &&
        (host->getIPv4Reservation() == IOAddress("0.0.0.0")) &&
        (!host->hasIPv6Reservation())) {
        std::ostringstream s;
        if (hwaddr) {
            s << "for DUID: " << hwaddr->toText();
        } else if (duid) {
            s << "for HW address: " << duid->toText();
        }
        isc_throw(BadValue, "specified reservation " << s
                  << " must include at least one resource, i.e. "
                  "hostname, IPv4 address or IPv6 address/prefix");
    }

    // Check for duplicates for the specified IPv4 subnet.
    if ((host->getIPv4SubnetID() > 0) &&
        get4(host->getIPv4SubnetID(), hwaddr, duid)) {
        isc_throw(DuplicateHost, "failed to add new host using the HW"
                  " address '" << (hwaddr ? hwaddr->toText(false) : "(null)")
                  << " and DUID '" << (duid ? duid->toText() : "(null)")
                  << "' to the IPv4 subnet id '" << host->getIPv4SubnetID()
                  << "' as this host has already been added");

    }
    /// @todo This may need further sanity checks.

    // This is a new instance - add it.
    hosts_.insert(host);
}

void
CfgHosts::add6(const HostPtr& host) {

    /// @todo This may need further sanity checks.
    HWAddrPtr hwaddr = host->getHWAddress();
    DuidPtr duid = host->getDuid();

    // Check for duplicates for the specified IPv6 subnet.
    if (host->getIPv6SubnetID() &&
               get6(host->getIPv6SubnetID(), duid, hwaddr)) {
        isc_throw(DuplicateHost, "failed to add new host using the HW"
                  " address '" << (hwaddr ? hwaddr->toText(false) : "(null)")
                  << " and DUID '" << (duid ? duid->toText() : "(null)")
                  << "' to the IPv6 subnet id '" << host->getIPv6SubnetID()
                  << "' as this host has already been added");
    }

    // Now insert it into hosts_, which will be used for finding hosts
    // based on their HW or DUID addresses. It cannot be used for
    // finding IPv6 hosts by their IPv6 addresses, as there may be multiple
    // addresses for a given host. However, insert only if this
    // host doesn't have v4 subnet-id. If it does, it was just added
    // by the previous call to add4().
    if (! host->getIPv4SubnetID()) {
        hosts_.insert(host);
    }

    // Get all reservations for this host.
    IPv6ResrvRange reservations = host->getIPv6Reservations();

    if (std::distance(reservations.first, reservations.second) == 0) {

        /// @todo: We don't handle address-less reservations yet
        return;
    }

    for (IPv6ResrvIterator it = reservations.first; it != reservations.second;
         ++it) {
        hosts6_.insert(HostResrv6Tuple(it->second, host));
    }
}

} // end of namespace isc::dhcp
} // end of namespace isc
