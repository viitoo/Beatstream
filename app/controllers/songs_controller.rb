# -*- encoding : utf-8 -*-
require 'find'
require 'logger'

MUSIC_PATH = Rails.application.config.music_paths

SONGS_JSON_FILE = Rails.root.join('data/songs.json')

class SongsController < ApplicationController

    # GET /songs
    def index
        songs_json = '';

        if params[:refresh]
            Rails.logger.info 'Forced songs JSON refresh'
            refresh(songs_json)
        end

        begin
            f = File.open(SONGS_JSON_FILE, 'r')
            Rails.logger.info 'Songs JSON last modified: ' + f.mtime.to_s
            songs_json = f.read
        rescue Errno::ENOENT
            Rails.logger.info 'Songs JSON file not found --> refreshing songs list'
            refresh(songs_json)
        end

        render :text => songs_json
    end

    # GET /songs/play
    def play
        if params[:file].nil?
            render :status => :bad_request, :text => "missing required parameter 'file'"
            return
        end

        filepath = MUSIC_PATH + params[:file]

        response.content_type = Mime::Type.lookup_by_extension("mp3")

        # Dumb read streaming
        render :text => File.open(filepath, 'rb') { |f| f.read }

        # True streaming?
        #send_file filepath, :type => 'audio/mpeg'
    end

    private

    def refresh(songs_as_json)
        songs = []

        # TODO: TEST THAT Dir.glob RETURNS THE SAME SET OF SONGS AS Find.find !!111!21!112!!!#!3121

        #Find.find(MUSIC_PATH) do |file|
        Dir.chdir(MUSIC_PATH)
        Dir.glob('**/*').each do |file|
            @invalid = false
            file = sanitize(file)

            if @invalid
                Rails.logger.warn "#{file} Contains Invalid UTF-8 byte sequences"
                # TODO: collect files with invalid UTF-8 and show them to the user
            end

            # Skip directories
            if File.directory?(file)
                next
            end

            # Skip non-mp3 files
            if file !~ /.*\.mp3$/i || file =~ /^\./
#                Rails.logger.info 'Skipping file as not MP3 file: ' + file
                next
            end

            begin
                mp3 = Song.new(file, songs.length)
                songs.push(mp3)
            rescue Exception => e
                Rails.logger.info e
                Rails.logger.info 'Failed to load MP3: ' + file
                # TODO: collect the broken mp3s into a separate array
                # TODO: count the broken mp3s
            end
        end

        songs = songs.sort_by { |song| song.to_natural_sort_string }

        songs_as_json = songs.to_json
        File.open(SONGS_JSON_FILE, 'w') { |f| f.write(songs_as_json) }
    end

    def sanitize(str)
        str.each_char.map do |char|
          begin
            char if !!char.unpack('U')
          rescue
            @invalid = true
            "\xEF\xBF\xBD" # => "\uFFFD"
          end
        end.join
    end
end
