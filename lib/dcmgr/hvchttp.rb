# -*- coding: utf-8 -*-

require 'net/http'

module Dcmgr
  module HvcAccess
    def run_instance(hva_ip, instance_uuid, instance_ip, instance_mac,
                     cpus, cpu_mhz, memory, *opts)
      _get("/?action=run_instance&hva_ip=#{hva_ip}&" \
           + "instance_uuid=#{instance_uuid}&instance_ip=#{instance_ip}&instance_mac=#{instance_mac}&cpus=1&cpu_mhz=1.0&memory=2.0",
           opts)
    end

    def terminate_instance(hva_ip, instance_uuid, *opts)
      _get("/?action=terminate_instance&hva_ip=#{hva_ip}&instance_uuid=#{instance_uuid}",
           opts)
    end

    def describe_instances(*opts)
      _get("/?action=describe_instances", opts)
    end

    def _get(url, opts)
      if opts.include? :url_only
        url
      else
        ret = get(url)
      end
    end
  end
  
  class HvcHttp
    include HvcAccess
    def open(host, port=3000, &block)
      Net::HTTP.start(host, port) {|http|
        http.extend HvcAccess
        block.call(http)
      }
    end
  end
end
