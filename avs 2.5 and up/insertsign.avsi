# fixed ver. to deal with HD video correctly v.1.44 mod by AmjadSONY
# need Zs_RF_Shared.avsi

function insertsign(clip mainclip, clip overlayclip, int startframe, int "endframe", int "xoffset", int "yoffset", int "fad1", int "fad2", bool "alpha", string "matrix", clip "External") {
sisavs26   = !(VersionNumber() < 2.60)
sisphbd = sisavs26 ? AvsPlusVersionNumber > 2294 : 0
shasalpha = sisavs26 ? AvsPlusVersionNumber >= 2359 ? overlayclip.HasAlpha() : overlayclip.IsRGB32() : overlayclip.IsRGB32()
	# make the endframe parameter optional (defaulting to where the overlay clip ends)
	endframe = default(endframe,startframe+overlayclip.framecount-1)
	endframe = (endframe == 0) ? startframe+overlayclip.framecount()-1 : endframe
	endframe = (endframe >= mainclip.framecount()-1) ? mainclip.framecount()-1 : endframe
	bExternal = defined(External)
	alpha = default(alpha, shasalpha)
	sisnrgb = !(mainclip.isrgb())
	matrix = default(matrix, !bExternal && sisnrgb ? sisphbd ? mainclip.BitsPerComponent() > 8 && mainclip.width() > 1440 ? "rec2020" : mainclip.height() >= 600 ? "Rec709" : "Rec601" :  mainclip.height() >= 600 ? "Rec709" : "Rec601" : "") #dirty hack to check matrix
	matrix = matrix == "" ? undefined : matrix
	
	# make sure the special case startframe=1 is dealt with correctly
	# (needed because trim(0,0) returns the entire clip, which is obviously not what we want)
	# note that the first frame of the clip is ZER0, _not_ one!
	begin	= (startframe == 1) ? mainclip.trim(0,-1) : mainclip.trim(0,startframe-1)
	middle	= mainclip.trim(startframe,endframe)
	end	= (endframe == mainclip.framecount()-1) ? blankclip(mainclip,length=0) : mainclip.trim(endframe+1,0)
	
	shasalp = sisphbd ? middle.IsRGB64() || middle.IsRGB32() : middle.IsRGB32()
	alphaclip = !shasalp && alpha ? sisphbd ? overlayclip.ExtractA() : overlayclip.showalpha() : nop()
	bfad1 = defined(fad1)
	bfad2 = defined(fad2)
	alphaclip = !shasalp && alpha ? bfad1 && bfad1 ? alphaclip.trim(0, endframe-startframe).FadeIn0(fad1).FadeOut0(fad2) : bfad1 ? alphaclip.trim(0, endframe-startframe).FadeIn0(fad1) : bfad2 ? alphaclip.trim(0, endframe-startframe).FadeOut0(fad2) : alphaclip : undefined
	middleoverlay = shasalp ? Layer(middle,overlayclip, "add", x=xoffset, y=yoffset) : Overlay(middle, bExternal ? External : defined(matrix) && overlayclip.IsRGB() && sisnrgb ? !sisavs26 ? \
	overlayclip.ConvertToYV12(matrix=matrix) : \
	sisphbd ? overlayclip.ConvertToYUV444(matrix=matrix) : overlayclip.ConvertToYV24(matrix="Rec709") : overlayclip, mask=alphaclip, x=xoffset, y=yoffset)
	
	# deal with the special case startframe=0 (in which case we don't have anything before the overlay)
	# note that trim(-1,0) does nothing (it returns the same as trim(0,0)...)
	
	final = (startframe == 0) ? middleoverlay ++ end : begin ++ middleoverlay ++ end
	return final
}

# insert_types 1.01 for avs by A.SONY, clean up by StainlessS
# need RT_Stats, and in non plus avs it also need GSCript
Function insert_types(clip clp, string dir, string "container", string "sourcecall") {
    Assert(dir!="", "insert_types: you must set the dir")                               # We made Dir Non Optional
    WildCard=Default(container,"*.AVI")
    sourcecall=Default(sourcecall,"ffms2")
    clp
    eS=RightStr(dir,1)
    Path=(eS!="\" && eS!="/") ? dir+"\" : dir                                           # Ensure End Slash
    TestPath=LeftStr(Path,Strlen(Path)-1)                                               # Test PATH Exist without End Slash, else Error
    Assert(Exist(TestPath),"insert_types: Path Does not exist ("+Path+")")
    SearchString = Path + WildCard
    TMPFile=RT_GetSystemEnv("TEMP") + "\~AVIVid_" + RT_LocalTimeString(file=True) + ".TMP"      # Unique name in User TEMP directory
    LineCount = RT_WriteFileList(SearchString,TMPFile)
    scstr= """
        for(Line = 0, LineCount - 1) {                                                  # Line = zero relative line number
            s=TMPFile.RT_ReadTxtFromFile(Lines=1,Start=Line).RT_TxtGetLine(Line=0)      # Read single Line from file, convert to single line string [not multi-line ie strip NewLine Chr(10)]
            fi=FindStr(s,"_")
            fr=s.MidStr(fi+1).Value.Int
            last.insertsign(eval(sourcecall+string("(s)")),fr)
        }
        RT_FileDelete(TMPFile)                                                          # Dump file when done with it
    """
    IsAvsPlus ? eval(scstr) : GSCript(scstr)                                            # External dll overrides builtin plugs, perhaps user intended GScript to be used if is in Plugins dir.
    return last
}