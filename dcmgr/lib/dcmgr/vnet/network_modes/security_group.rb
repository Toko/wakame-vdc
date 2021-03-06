# -*- coding: utf-8 -*-

module Dcmgr::VNet::NetworkModes

  class SecurityGroup
    include Dcmgr::Helpers::NicHelper
    include Dcmgr::VNet::Tasks

    def netfilter_all_tasks(vnic,network,friends,security_groups,node)
      tasks = []

      host_addr = Isono::Util.default_gw_ipaddr
      enable_logging = Dcmgr.conf.packet_drop_log
      ipset_enabled = Dcmgr.conf.use_ipset

      # Drop all traffic that isn't explicitely accepted
      tasks += self.netfilter_drop_tasks(vnic,node)

      # General data link layer tasks
      tasks << AcceptARPToHost.new(host_addr,vnic[:address],enable_logging,"A arp to_host #{vnic[:uuid]}: ")
      tasks << AcceptARPFromGateway.new(network[:ipv4_gw],enable_logging,"A arp from_gw #{vnic[:uuid]}: ") unless network[:ipv4_gw].nil?
      tasks << AcceptARPFromDNS.new(network[:dns_server],enable_logging,"A arp from_dns #{vnic[:uuid]}: ") unless network[:dns_server].nil?
      tasks << DropIpSpoofing.new(vnic[:address],enable_logging,"D arp sp #{vnic[:uuid]}: ")
      tasks << DropMacSpoofing.new(clean_mac(vnic[:mac_addr]),enable_logging,"D ip sp #{vnic[:uuid]}: ")
      tasks << AcceptArpBroadcast.new(host_addr,enable_logging,"A arp bc #{vnic[:uuid]}: ")

      # General ip layer tasks
      tasks << AcceptIcmpRelatedEstablished.new
      tasks << AcceptTcpRelatedEstablished.new
      tasks << AcceptUdpEstablished.new
      #tasks << AcceptAllDNS.new
      tasks << AcceptWakameDNSOnly.new(network[:dns_server]) unless network[:dns_server].nil?
      tasks << AcceptWakameDHCPOnly.new(network[:dhcp_server]) unless network[:dhcp_server].nil?

      # VM isolation based
      tasks += self.netfilter_isolation_tasks(vnic,friends,node)
      tasks += self.netfilter_nat_tasks(vnic,network,node)

      # Accept ip traffic from the gateway that isn't blocked by other tasks
      tasks << AcceptIpFromGateway.new(network[:ipv4_gw]) unless network[:ipv4_gw].nil?

      # Security group rules
      security_groups.each { |secgroup|
        tasks += self.netfilter_secgroup_tasks(secgroup)

        # Accept ARP from referencing security groups
        ref_vnics = secgroup[:referencers].values.map {|rg| rg.values}.flatten.uniq
        tasks += self.netfilter_arp_isolation_tasks(vnic,ref_vnics,node)
      }

      tasks
    end

    def netfilter_nat_tasks(vnic,network,node)
      tasks = []

      # Nat tasks
      unless vnic[:nat_ip_lease].nil?
        tasks << StaticNatLog.new(vnic[:address], vnic[:nat_ip_lease], "SNAT #{vnic[:uuid]}", "DNAT #{vnic[:uuid]}") if Dcmgr.conf.packet_drop_log
        tasks << StaticNat.new(vnic[:address], vnic[:nat_ip_lease], clean_mac(vnic[:mac_addr]))
      end

      #TODO:Move this line out of nat tasks
      tasks << TranslateMetadataAddress.new(vnic[:uuid],network[:metadata_server],network[:metadata_server_port] || 80) unless network[:metadata_server].nil?

      tasks
    end

    def netfilter_isolation_tasks(vnic,friends,node)
      tasks = []
      enable_logging = Dcmgr.conf.packet_drop_log
      ipset_enabled = Dcmgr.conf.use_ipset

      friend_ips = friends.map { |friend| friend[:address] }.compact

      tasks << AcceptARPFromFriends.new(vnic[:address],friend_ips,enable_logging,"A arp friend #{vnic[:uuid]}")
      tasks << AcceptIpFromFriends.new(friend_ips)

      unless vnic[:nat_ip_lease].nil?
        # Friends don't use NAT, friends talk to each other with their REAL ip addresses.
        # It's a heart warming scene, really
        if ipset_enabled
          # Not implemented yet
          #tasks << ExcludeFromNatIpSet.new(friend_ips,vnic[:address])
        else
          #tasks << ExcludeFromNat.new(friend_ips,vnic[:address])
          tasks << ExcludeFromNat.new(friend_ips,vnic[:address])
        end
      end

      tasks
    end

    def netfilter_secgroup_tasks(secgroup)
      [Dcmgr::VNet::Tasks::SecurityGroup.new(secgroup)]
    end

    def netfilter_drop_tasks(vnic,node)
      enable_logging = Dcmgr.conf.packet_drop_log

      #TODO: Add logging to ip drops
      [DropIpFromAnywhere.new, DropArpForwarding.new(enable_logging,"D arp #{vnic[:uuid]}: "),DropArpToHost.new]
      #[DropIpFromAnywhere.new]
    end

    def netfilter_arp_isolation_tasks(vnic,friends,node)
      enable_logging = Dcmgr.conf.packet_drop_log

      friend_ips = friends.map { |friend| friend[:address] }.compact

      [AcceptARPFromFriends.new(vnic[:address],friend_ips,enable_logging,"A arp friend #{vnic[:uuid]}")]
    end
  end
  
end
