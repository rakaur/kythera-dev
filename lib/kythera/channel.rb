#
# kythera: services for IRC networks
# lib/kythera/channel.rb: Channel class
#
# Copyright (c) 2011 Eric Will <rakaur@malkier.net>
# Rights to this code are documented in doc/license.txt
#

require 'kythera'

# A list of all channels; keyed by channel name by default
$channels = IRCHash.new

# This is just a base class; protocol module should subclass this
class Channel
    # Standard IRC status cmodes
    @@status_modes = { 'o' => :operator,
                       'v' => :voice }

    # Standard IRC list cmodes
    @@list_modes   = { 'b' => :ban }

    # Standard IRC cmodes requiring a param
    @@param_modes  = { 'l' => :limited,
                       'k' => :keyed }

    # Standard boolean IRC cmodes
    @@bool_modes   = { 'i' => :invite_only,
                       'm' => :moderated,
                       'n' => :no_external,
                       'p' => :private,
                       's' => :secret,
                       't' => :topic_lock }

    # Attribute reader for `@@status_modes`
    #
    # @return [Hash] a list of all status modes
    #
    def self.status_modes
        @@status_modes
    end

    # The channel name, including prefix
    attr_reader :name

    # If the channel is +k, this is the key
    attr_reader :key

    # A Hash of members keyed by nickname
    attr_reader :members

    # An Array of mode Symbols
    attr_reader :modes

    # Creates a new channel. Should be patched by the protocol module.
    def initialize(name)
        @name   = name
        @modes  = []

        # Keyed by nickname by default
        @members = IRCHash.new

        $channels[name] = self

        $log.debug "new channel: #{@name}"

        $eventq.post(:channel_added, self)
    end

    public

    # String representation is just `@name`
    def to_s
        @name
    end

    # Parses a mode string and updates channel state
    #
    # @param [String] modes the mode string
    # @param [Array] params params to the mode string, tokenized by space
    #
    def parse_modes(modes, params)
        action = nil # :add or :delete

        modes.each_char do |c|
            mode, param = nil

            if c == '+'
                action = :add
                next
            elsif c == '-'
                action = :delete
                next
            end

            # Status modes
            if @@status_modes.include?(c)
                mode  = @@status_modes[c]
                param = params.shift

            elsif @@list_modes.include?(c)
                mode  = @@list_modes[c]
                param = params.shift

            # Always has a param (some send the key, some send '*')
            elsif c == 'k'
                mode  = :keyed
                param = params.shift
                @key  = action == :add ? param : nil

            # Has a param when +, doesn't when -
            elsif @@param_modes.include?(c)
                mode   = @@param_modes[c]
                param  = params.shift

                if action == :add
                    instance_variable_set("@#{mode}", param)

                    Channel.class_exec do
                        attr_reader mode.to_sym
                    end
                else
                    instance_variable_set("@#{mode}", nil)
                end

            # The rest, no param
            elsif @@bool_modes.include?(c)
                mode = @@bool_modes[c]
            end

            # Add boolean modes to the channel's modes
            unless @@status_modes.include?(c) or @@list_modes.include?(c)
                if action == :add
                    @modes << mode
                else
                    @modes.delete(mode)
                end
            end

            unless @@status_modes.include?(c)
                $log.debug "mode #{action}: #{self} -> #{mode} #{param}"
            end

            # Status modes for users get tossed to another method so that
            # how they work can be monkeypatched by protocol modules
            #
            parse_status_mode(action, mode, param) if @@status_modes.include?(c)

            # Post an event for it
            if action == :add
                $eventq.post(:mode_added_on_channel, mode, param, self)
            elsif action == :delete
                $eventq.post(:mode_deleted_on_channel, mode, param, self)
            end
        end
    end

    # Adds a User as a member
    #
    # @param [User] user the User to add
    #
    def add_user(user)
        @members[user.key] = user

        $log.debug "user joined #{self}: #{user} (#{@members.length})"

        $eventq.post(:user_joined_channel, user, self)
    end

    # Deletes a User as a member
    #
    # @param [User] user User object to delete
    #
    def delete_user(user)
        @members.delete(user.key)

        user.status_modes.delete(self)

        $log.debug "user parted #{self}: #{user} (#{@members.length})"

        $eventq.post(:user_parted_channel, user, self)

        if @members.length == 0
            $channels.delete @name

            $log.debug "removing empty channel #{self}"

            $eventq.post(:channel_deleted, self)
        end
    end

    # Does this channel have the specified mode set?
    #
    # @param [Symbol] mode the mode symbol
    # @return [Boolean] true or false
    #
    def has_mode?(mode)
        @modes.include?(mode)
    end

    # Deletes all modes
    def clear_modes
        @modes = []
    end

    private

    # Deals with status modes
    #
    # @param [Symbol] mode Symbol representing a mode flag
    # @param [String] target the user this mode applies to
    #
    def parse_status_mode(action, mode, target)
        unless user = $users[target]
            $log.warn "cannot parse a status mode for an unknown user"
            $log.warn "#{target} -> #{mode} (#{self})"

            return
        end

        if action == :add
            user.add_status_mode(self, mode)
        elsif action == :delete
            user.delete_status_mode(self, mode)
        end
    end
end
