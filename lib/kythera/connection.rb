#
# kythera: services for TSora IRC networks
# lib/kythera/connection.rb: handles the networking
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in LICENSE
#

require 'kythera'
require 'kythera/loggable'

# Provides all of our networking needs
class Connection < Cool.io::TCPSocket
    include Loggable

    public

    def connected?
        @connected
    end

    private

    # Called when a connection is established
    def on_connect
        @connected = true

        log.info "successfully connected to #{@remote_host}:#{@remote_port}"
    end

    # Called when a connection fails
    def on_connect_failed
        @connected = false
    end

    # Called when the connection is closed or lost
    def on_close
        @connected = false

        log.info "lost connection to #{@remote_host}:#{@remote_port}"
        # XXX events here...
    end

    # Called when data has been read and is waiting to be parsed
    def on_read(data)
        log.debug "#{@remote_host}:#{@remote_port} -- #{data.chomp}"
    end
end