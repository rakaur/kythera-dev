# -*- Mode: Ruby; tab-width: 4; indent-tabs-mode: nil; -*-
#
# kythera: services for IRC networks
# lib/kythera/protocol/ts6.rb: implements the TS6 protocol
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.md
#

require 'kythera'

module Protocol::TS6
end

require 'kythera/protocol/ts6/channel'
require 'kythera/protocol/ts6/receive'
require 'kythera/protocol/ts6/send'
require 'kythera/protocol/ts6/server'
require 'kythera/protocol/ts6/user'

# Implements TS6 protocol-specific methods
module Protocol::TS6
    include Protocol

    # The current UID for Services
    @@current_uid = 'AAAAAA'

    public

    # Makes one of our clients join a channel
    #
    # @param [String] origin the entity joining the channel
    # @param [String] target the channel to join
    #
    def join(origin, target)
        assert { { :origin => String, :target => String } }

        unless user = $users[origin]
            $log.warn 'cannot join nonexistent user to channel'
            $log.warn "#{origin} -> #{target}"

            return
        end

        unless channel = $channels[target]
            # This is a nonexistent channel
            channel = Channel.new(target)
        end

        # Use SJOIN only to create a channel
        if channel.members.empty?
            ret = send_sjoin(channel.name, channel.timestamp, user.uid)

            # SJOIN automatically ops them, keep state
            user.add_status_mode(channel, :operator)
            $eventq.post(:mode_added_on_channel, :operator, user, channel)
        else
            ret = send_join(user.uid, channel.name, channel.timestamp)
            toggle_status_mode(user, channel, :operator)
        end

        # Keep state
        channel.add_user(user)

        ret
    end

    # Send a set of modes contained in a ChannelMode to the uplink
    #
    # @params [Protocol::ChannelMode] cmode the ChannelMode to process
    #
    def format_and_send_channel_mode(cmode)
        #assert { { :cmode => ::Protocol::ChannelMode } }

        modes, params = format_channel_mode(cmode)

        modestr   = "#{modes} #{params}"
        origin    = cmode.user ? cmode.user.key : nil
        target    = cmode.channel.name
        timestamp = cmode.channel.timestamp

        send_tmode(origin, target, timestamp, modestr)

        Protocol::ChannelMode.delete(cmode)
    end
end
