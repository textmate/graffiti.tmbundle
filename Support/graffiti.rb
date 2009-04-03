#!/usr/bin/env ruby


###############################################################################
# Test cases.
# hal_Open
# memd_FlashOpen
# HAL_ASSERT
# HAL_CFG_CONFIG_T
#


###############################################################################
# The tools ctags and cscope are in the directory ('$TM_BUNDLE_SUPPORT/bin').
#
require ENV['TM_SUPPORT_PATH'] + '/lib/web_preview.rb'
require ENV['TM_SUPPORT_PATH'] + '/lib/textmate.rb'
require ENV['TM_SUPPORT_PATH'] + '/lib/ui.rb'
require 'yaml'


###############################################################################
# Module Graffiti, containing all the methods and data members of the bundle.
#
module Graffiti


    ###############################################################################
    # Module data members.
    #
    # Define the locations of the tag and history files.
    #
    # TODO: check also the TM_PROJECT_FILEPATH variable.
    #
    @@bundleName = "Graffiti"
    @@ctags = "\"#{ENV['TM_BUNDLE_SUPPORT']}/bin/ctags\""
    @@cscope = "\"#{ENV['TM_BUNDLE_SUPPORT']}/bin/cscope\""
    @@projectDirPath = ENV['TM_PROJECT_DIRECTORY']
    @@prefDirPath = @@projectDirPath + '/.graffiti'
    @@ctagsTagFilePath = @@prefDirPath + '/ctags.tags'
    @@cscopeTagFilePath = @@prefDirPath + '/cscope.out'
    @@cscopeDbFilePath = @@prefDirPath + '/cscope.files'
    @@historyFilePath = @@prefDirPath + '/history.yaml'
    @@ctagsIdentifiers = "VOID=void"


    ###############################################################################
    # askCscope
    #
    # Query cscope with a 'symbol' name and a 'cmdId' command number and build
    # and return the array 'tagsTable' with query result. 'tagsTable' contains
    # one line per result found by cscope. This line contains:
    # 0 - File path.
    # 1 - Symbol name.
    # 2 - Line number.
    # 3 - Text of the line where the definition has been found.
    # The returned table cannot be null, but can be empty.
    # 
    def askCscope(cmdId, symbol)
        checkTagFiles()

        tagsTable = []
        # -d     Do not update the cross-reference.
        # -L     Do a single search with line-oriented output.
        # -q     Enable fast symbol lookup via an inverted index.
        cscopeAskCmd = "cd '#{@@prefDirPath}' && " +
        "#{@@cscope} -L -q -d -#{cmdId}\"#{symbol}\""
        cscopeCmdResult = `#{cscopeAskCmd}`
        cscopeCmdResult.each_line { |line|
            lineArray = line.chop.split(" ")
            tagsTable << [lineArray[0..2], lineArray[3..-1].join(" ")].flatten
        }

        return tagsTable
    end


    ###############################################################################
    # askCscopePopupResults
    #
    # Query cscope with a 'symbol' name and a 'cmdId' command number and ask the
    # user to choose one, with a popup menu, if multiple occurrences are found.
    # Return an array containing:
    # 0 - File path.
    # 1 - Symbol name.
    # 2 - Line number.
    # 3 - Text of the line where the definition has been found.
    # The returned table cannot be null and cannot be empty. If nothing found
    # or selected by user, show a tool tip and exit.
    # 
    def askCscopePopupResults(cmdId, symbol)
        # Ask to cscope the list of locations.
        tagsTable = askCscope(cmdId, symbol)

        if (tagsTable.size == 0) then
            # No match.
            raise "Nothing found."
        elsif (tagsTable.size == 1)
            # Only one match.
            selected = 0
        else
            # Multiple occurrences, display a selection menu.
            # Build the array 'tagsMenu' containing only the paths.
            tagsMenu = []
            tagsTable.each{ |tagsTableLine|
                tagsMenu << tagsTableLine[0].sub(@@projectDirPath, '')
            }
            selected = TextMate::UI.menu(tagsMenu)
            # Esc pressed.
            exit if (selected == nil)
        end

        # Return the selected file.
        return tagsTable[selected]
    end


    ###############################################################################
    # displayTagsTable
    #
    # Get a tags table returned by ask cscope function and display it as a list
    # in a nice HTML output.
    # 
    def displayTagsTable(title, tagsTable)
        raise "Nothing found." if tagsTable.empty?

        html_header(title, @@bundleName)
        print "<ul>\n"
        
        tagsTable.each{ |tagLine|
            filepath = tagLine[0]
            fileshortpath = tagLine[0].sub(@@projectDirPath, '')
            filename = File.basename(tagLine[0])
            symbol = tagLine[1]
            line = tagLine[2]
            text = tagLine[3]

            print "<li>In <b>#{filename}</b> line #{line} - <code>"
            print "<a href='txmt://open?url=file://#{filepath}" +
            "&line=#{line}&column=0'>#{fileshortpath}</a></code><br/>\n"
            print "<code><small><font color='grey'>#{text}</font></small></code><br/><br/>\n"
#            print "<pre><font color='grey'>#{text}</font></pre>\n"
#            print "<code><font color='grey'>#{text}</font></code><br/><br\>\n"
        }
        
        print "</ul>\n"
        html_footer
        
        TextMate.exit_show_html
    end
    
    
    ###############################################################################
    # findLocationsOfCurrentSymbol
    #
    # Ask to cscope the locations where the symbol can be found,
    # and print it out as a nice HTML list.
    # 
    def findLocationsOfCurrentSymbol()
        title = "Locations of \"#{getCurrentWord()}\""
        displayTagsTable(title, askCscope(0, getCurrentWord()))        
    rescue => msg
        toolTip(msg)
    end


    ###############################################################################
    # jumpToLocationOfCurrentSymbol
    #
    # Ask to cscope the locations where the symbol can be found,
    # ask the user via popup to choose one and jump to it at the proper line.
    # 
    def jumpToLocationOfCurrentSymbol()
        jumpToTagLine(askCscopePopupResults(0, getCurrentWord()))
    rescue => msg
        toolTip(msg)
    end


    ###############################################################################
    # findDefinitionsOfCurrentWord
    #
    # Ask to cscope where the symbol is defined,
    # and print it out as a nice HTML list.
    # 
    def findDefinitionsOfCurrentWord()
        title = "Definitions of \"#{getCurrentWord()}\""
        displayTagsTable(title, askCscope(1, getCurrentWord()))        
    rescue => msg
        toolTip(msg)
    end


    ###############################################################################
    # jumpToDefinitionOfCurrentWord
    #
    # Ask to cscope where the symbol is defined,
    # ask the user via popup to choose one and jump to it at the proper line.
    # 
    def jumpToDefinitionOfCurrentWord()
        jumpToTagLine(askCscopePopupResults(1, getCurrentWord()))
    rescue => msg
        toolTip(msg)
    end


    ###############################################################################
    # findFunctionsCallingCurrentFunction
    #
    # Ask to cscope where the function under the cursor is called,
    # and print it out as a nice HTML list.
    # 
    def findFunctionsCallingCurrentFunction()
        title = "Callers of \"#{getCurrentWord()}\""
        displayTagsTable(title, askCscope(3, getCurrentWord()))        
    rescue => msg
        toolTip(msg)
    end


    ###############################################################################
    # jumpToFunctionCallingCurrentFunction
    #
    # Ask to cscope where the function under the cursor is called,
    # ask the user via popup to choose one and jump to it at the proper line.
    # 
    def jumpToFunctionCallingCurrentFunction()
        jumpToTagLine(askCscopePopupResults(3, getCurrentWord()))
    rescue => msg
        toolTip(msg)
    end


    ###############################################################################
    # findFilesIncludingCurrentFile
    #
    # Ask to cscope where the current file is #included,
    # and print it out as a nice HTML list.
    # 
    def findFilesIncludingCurrentFile()
        title = "Inclusions of \"#{getCurrentFileName()}\""
        displayTagsTable(title, askCscope(8, getCurrentFileName()))        
    rescue => msg
        toolTip(msg)
    end


    ###############################################################################
    # jumpToFileIncludingCurrentFile
    #
    # Ask to cscope where the current file is #included,
    # ask the user via popup to choose one and jump to it at the proper line.
    # 
    def jumpToFileIncludingCurrentFile()
        jumpToTagLine(askCscopePopupResults(8, getCurrentFileName()))
    rescue => msg
        toolTip(msg)
    end


    ###############################################################################
    # loadJumpHistory
    #
    # Return a table containing the previous locations.
    # This table can be empty but not null.
    # 
    def loadJumpHistory()
        return [] unless FileTest.exist?(@@historyFilePath)
        history = File.open(@@historyFilePath) { |yf| YAML::load(yf) }
        return [] if history == false
        return history
    end


    ###############################################################################
    # saveJumpHistory
    #
    # Save a table containing the previous locations.
    # This table can be empty but not null.
    # 
    def saveJumpHistory(history)
        File.open(@@historyFilePath, 'w') { |yf| YAML.dump(history, yf) }
    end


    ###############################################################################
    # jumpToTagLine
    #
    # Jump to a location returned by ask cscope functions.
    # 
    def jumpToTagLine(tagLine)
        jumpToFile(tagLine[0], tagLine[2].to_i, 0)
    end


    ###############################################################################
    # jumpToFile
    #
    # Jump to 'file' at 'line' and 'column' and add the current location to
    # the history.
    # 
    def jumpToFile(file, line, column)
        # Load the history array.
        history = loadJumpHistory()

        # Save the current location in the history array.
        history.push({:file => ENV['TM_FILEPATH'], :line => ENV['TM_LINE_NUMBER'].to_i, :column => ENV['TM_COLUMN_NUMBER'].to_i})
        
        # Save the history array.
        saveJumpHistory(history)
        
        # Open the selected file at the right line and column.
        TextMate::go_to({:file => file, :line => line, :column => column})
    end


    ###############################################################################
    # jumpBack
    #
    # Jump to the previous location in the history.
    # Delete this location from history.
    # 
    def jumpBack()
        # Load the history array.
        history = loadJumpHistory()
        raise "History is empty." if history.empty?
        
        # Get the last location from history, remove this location from the
        # history and open this location.
        TextMate::go_to(history.pop)

        # Save the history array.
        saveJumpHistory(history)
        
    rescue => msg
        toolTip(msg)
    end


    ###############################################################################
    # completeCurrentWord
    #
    # Use the *ctags* file to display a list of completion proposals as a popup.
    # TODO: Find out why '_' is not handled as a normal char, as expected.
    # 
    def completeCurrentWord()
        currentWord = getCurrentWord()
        checkTagFiles()

        # Build the list of completion choice.
        choices = []
        grepCmd = "grep '^#{currentWord}' #{@@ctagsTagFilePath} | " +
        "sed -e 's/^\\(#{currentWord}[[:alnum:]_]*\\).*/\\1/p' -e 'd' | sort -u"
        `#{grepCmd}`.split("\n").each { |tagLine|
            choices += [{'display' => tagLine, 'match' => tagLine.sub(currentWord, '')}]
        }

        raise "Nothing found." if choices.size == 0

        # Display the completion popup.
        options = {:extra_chars => '_', :case_insensitive => false}
        TextMate::UI.complete(choices, options)
        
    rescue => msg
        toolTip(msg)
    end


    ###############################################################################
    # updateTagFiles
    #
    # Create the prefDirPath if needed. Create ctags and cscope tag files
    # starting from projectDirPath. Display this in a nice HTML output.
    #
    # TODO: Try the option "−L file" of ctags.
    # TODO: Try the option "−k" of cscope.
    # TODO: Add a way to exclude some directories.
    # TODO: Try to see if it is possible to just update the cscope database.
    #
    def updateTagFiles()
        html_header("Updating Tags", @@bundleName)
        print "Updating the tag files for <code>#{@@projectDirPath}</code>.<br/><br/>\n"
        print "<ul>\n"

        Dir.mkdir(@@prefDirPath) unless FileTest.directory?(@@prefDirPath);

        # Generate the ctags tag file.
        print "<li>Updating ctags file...<br/>\n"
        
        ctagsUpdateCmd = "cd '#{@@projectDirPath}' && " +
        "time #{@@ctags} --recurse --extra=+f --fields=-a+i+k+l-m+S+z-s-n-f-K " +
        "--excmd=number -I #{@@ctagsIdentifiers} --c-kinds=+p+x " +
        "-f '#{@@ctagsTagFilePath}'"

        print '<pre style="word-wrap: break-word;">'
        #print ctagsUpdateCmd + "<br/>\n" #DEBUG
        STDOUT.flush
        cmd = open("|#{ctagsUpdateCmd} 2>&1")
        cmd.each_line do |line|
            STDOUT.flush
            print(line)
        end
        print "Done.</pre>\n"

        # Generate the cscope tag file.
        print "<li>Updating cscope file...<br/>\n"
        
        cscopeUpdateCmd = "cd '#{@@prefDirPath}' && " +
        "find '#{@@projectDirPath}' -name \\*\.c -o -name \\*\.h -o -name \\*\.m -o -name \\*\.java " +
        " > '#{@@cscopeDbFilePath}' && " +
        "time #{@@cscope} -b -q"

        print '<pre style="word-wrap: break-word;">'
        #print cscopeUpdateCmd + "<br/>\n" #DEBUG
        STDOUT.flush
        cmd = open("|#{cscopeUpdateCmd} 2>&1")
        cmd.each_line do |line|
            STDOUT.flush
            print(line)
        end
        print "Done.</pre>\n"

        print "</ul><br/>Update complete.\n"

    ensure
        html_footer
    end
    
    
    ###############################################################################
    # toolTip
    #
    # Show an HTML tooltip displaying 'msg'.
    #
    def toolTip(msg)
        TextMate::UI.tool_tip(msg, {:format => :html})
    end


    ###############################################################################
    # checkTagFile
    #
    # Check that the ctags and cscope tag files are present.
    #
    # TODO: Add the check for cscope.
    #
    def checkTagFiles()
        raise "No tag file found, call 'Update tags' command." unless FileTest.exist?(@@ctagsTagFilePath)
    end


    ###############################################################################
    # getCurrentWord
    #
    # Get the word under the cursor, raise when nothing under the cursor.
    #
    def getCurrentWord()
        currentWord = ENV['TM_CURRENT_WORD']
        raise "Nothing under the cursor." if currentWord.nil?
        return currentWord
    end


    ###############################################################################
    # getCurrentFile
    #
    # Get the basename of the file currently opened, raise when empty (?).
    #
    def getCurrentFileName
        currentFile = File.basename(ENV['TM_FILEPATH']) # TM_SELECTED_FILE ?
        raise "No current file." if currentFile.nil?
        return currentFile
    end


end
