#!/usr/bin/env bash

HARDWARE_DECODE=1
HARDWARE_ENCODE=0
HEVC=0
SOURCE=""
DEST=""


for i in "$@"
do
    case $i in
        --hw)
            HARDWARE_ENCODE=1
            shift
        ;;
        --hevc)
            HEVC=1
            shift
        ;;
        *)
            SOURCE=$1
            shift
            DEST=$1
            shift
            break
        ;;
    esac
done

if [[ -z "$SOURCE" ]] || [[ ! -r "$SOURCE" ]]; then
    echo "Source is not readable"
    exit 1;
fi

if [[ -z "$DEST" ]]; then
    echo "Destination cannot be empty"
    exit 1;
fi

GPU_DETECT=$(lspci | grep VGA)
GPU=
if [[ "$GPU_DETECT" =~ "Intel" ]]; then
    GPU=intel
elif [[ "$GPU_DETECT" =~ "Nvidia" ]]; then
    GPU=nvidia
elif [[ "$GPU_DETECT" =~ "AMD" ]]; then
    GPU=amd
fi

for line in $("${0%/*}/video-filter-streams" "$SOURCE"); do
    [ "$line" == "" ] && continue

    MAPS=${MAPS}$(echo -e "$line" | awk -F"|" '{split($1,stream,"=");printf "-map 0:%d ", stream[2]}')

    METADATA=${METADATA}$(echo -e "$line" | awk -F"|" ' \
        { \
            split($2,codec_type,"="); \
            split($5,lang,"="); \
            printf "-metadata:s:%s:%s language=%s ", substr(codec_type[2],1,1), NR-1, lang[2] \
        } \
    ')

    DISPOSITION=${DISPOSITION}$(echo -e "$line" | awk -F"|" ' \
        { \
            split($2,codec_type,"="); \
            split($3,disposition_default,"="); \
            split($4,forced,"="); \
            printf "-disposition:%s:%d ", substr(codec_type[2],1,1), NR-1 \
        }; \
        { if(forced[2] == 1) print "forced"; else if(disposition_default[2] == 1) print "default"; else print "0";} \
        { print " " } \
    ')
done

PREOPTS=""
ENCODER=
if [ $HARDWARE_DECODE == 1 ] || [ $HARDWARE_ENCODE == 1 ]; then
    if [ $GPU == "amd" ]; then
        PREOPTS="-hwaccel vaapi -hwaccel_device /dev/dri/renderD128 "
    fi
fi

# Default encoder
if [ $HEVC == 1 ]; then
    ENCODER="libx265 -crf 18 -preset medium"
else
    ENCODER="libx264 -crf 18 -preset medium"
fi

if [ $HARDWARE_ENCODE == 1 ]; then
    if [ $GPU == "amd" ]; then
        PREOPTS+="-hwaccel_output_format vaapi "

        if [ $HEVC == 1 ]; then
            ENCODER="hevc_vaapi -global_quality 18 "
        else
            ENCODER="h264_vaapi -global_quality 18 "
        fi
    fi
fi

set -o xtrace
exec ffmpeg \
    $PREOPTS \
    -y \
    -i "$SOURCE" \
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
    $( [ "${DEST##*.}" == 'mkv' ] && echo "-default_mode infer_no_subs" ) \
    -probesize 2048M \
    -analyzeduration 2048M \
    "$DEST"
