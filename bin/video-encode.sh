#!/usr/bin/env bash

ENTRIES="index,codec_type:stream_disposition=default,forced:stream_tags=language"

AUDIO_STREAMS=$(ffprobe -v error \
    -show_entries stream=$ENTRIES \
    -select_streams a \
    -of compact=p=0 \
    "$1" \
    | grep -i 'default=1\|forced=1\|language=eng\|language=und' \
)

SUBTITLE_STREAMS=$(ffprobe -v error \
    -show_entries stream=$ENTRIES \
    -select_streams s \
    -of compact=p=0 \
    "$1" \
    | grep -i 'language=eng\|language=und' \
)

declare -a STREAMS_ARRAY=("$AUDIO_STREAMS" "$SUBTITLE_STREAMS")
STREAMS_ARRAY_LENGTH=${#STREAMS_ARRAY[@]}
#
# use for loop to read all values and indexes
for (( i=0; i<${STREAMS_ARRAY_LENGTH}; i++ ));
do
    MAPS=${MAPS}$(echo -e "${STREAMS_ARRAY[$i]}" | awk -F"|" '{split($1,stream,"=");printf "-map 0:%d ", stream[2]}')

    METADATA=${METADATA}$(echo -e "${STREAMS_ARRAY[$i]}" | awk -F"|" ' \
        { \
            split($2,codec_type,"="); \
            split($5,lang,"="); \
            printf "-metadata:s:%s:%s language=%s ", substr(codec_type[2],1,1), NR-1, lang[2] \
        } \
    ')

    DISPOSITION=${DISPOSITION}$(echo -e "${STREAMS_ARRAY[$i]}" | awk -F"|" ' \
        { \
            split($2,codec_type,"="); \
            split($3,default,"="); \
            split($4,forced,"="); \
            printf "-disposition:%s:%d ", substr(codec_type[2],1,1), NR-1 \
        }; \
        { if(forced[2] == 1) print "forced"; else if(default[2] == 1) print "default"; else print "0";} \
        { print " " } \
    ')
done

PREOPTS="-hwaccel vaapi -hwaccel_device /dev/dri/renderD128 "
PREOPTS+="-hwaccel_output_format vaapi "

ENCODER="hevc_vaapi -global_quality 18 "
# ENCODER="libx265 -crf 18 -preset medium"
set -o xtrace
exec ffmpeg \
    $PREOPTS \
    -y \
    -i "$1" \
    -map 0:v \
    $MAPS \
    -map 0:d? \
    -map 0:t? \
    -map_metadata 0 \
    $METADATA \
    $DISPOSITION \
    -c copy \
    -c:v $ENCODER \
    `# If output is mkv, ffmpeg will default the first track if there are no other defaults for that stream type` \
    $( [ "${2##*.}" == 'mkv' ] && echo "-default_mode infer_no_subs" ) \
    -probesize 2048M \
    -analyzeduration 2048M \
    "$2"
