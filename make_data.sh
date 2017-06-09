#!/bin/bash

# Developed by: Daniel Angelov, 2016

# Defines
STOREDIR=/media/daniel/8a78d15a-fb00-4b6e-9132-0464b3a45b8b/3ddata/ModelNet40
MODELDIR=${STOREDIR}/models
SCRIPTDIR=${STOREDIR}/scripts
mkdir -p ${MODELDIR}/train
mkdir -p ${MODELDIR}/test
mkdir -p ${SCRIPTDIR}

DATADIR='/home/daniel/code/3dmodels/data/ModelNet40_fixed/'
MODELS=$(find ${DATADIR} -name *.off -print) # | tail -2
RES=32

# echo ${MODELS}
# # Set virtual display
# Xvfb :99 -screen 0 640x480x24 &> /dev/null &
# export DISPLAY=:99

PARALLELJ=0
# MAXPARALLELJOBS=$(($(nproc) * 2))
FACTOR=2.5 # per thread
MAXPARALLELJOBS=$(echo "($(nproc) * ${FACTOR} + 0.5)/1" | bc)

MODELID=0
MODELMAXID=$(echo ${MODELS} | wc -w)

# echo ${MODELS}
# echo 'Max models: '${MODELMAXID}

echo 'Starting '$MAXPARALLELJOBS' jobs in parallel'

x=0 # TODO: Test when rotations are not only around z
y=0
for z in `seq 0 15 345`; # otherwise 0 15 345
do
	SCRIPTNAME=${SCRIPTDIR}/new_script_${x}_${y}_${z}.mlx
    echo 'Working on: ' ${SCRIPTNAME}

    if [ ! -f {SCRIPTNAME} ]; then
    	sed 's/XANGLE/'${x}'/' mesh_rot_script.mlx > ${SCRIPTNAME}
    	sed -i 's/YANGLE/'${y}'/' ${SCRIPTNAME}
        sed -i 's/ZANGLE/'${z}'/' ${SCRIPTNAME}
    	echo 'Generated file for '${z}' deg'
    else
        echo 'Script file already exists.'
    fi

	echo 'Executing conversion'
    for m in ${MODELS};
    do
        # Split into testing and training sets
        if [[ "${m}" =~ "train" ]]; then
            # echo "Not Found"
            SETSPLIT="train"
        else
            SETSPLIT="test"
        fi

        # Generate model name
        NEWMODNAME=${MODELDIR}/${SETSPLIT}/${RES}_${x}_${y}_${z}_$(basename ${m})
        (( MODELID ++ ))
        echo 'At model '${MODELID}'/'${MODELMAXID}' @ z='${z}' - '$(basename ${m})

        NEWMODVOXNAME=${NEWMODNAME%.*}'.binvox'
        # echo ${NEWMODVOXNAME}

        # Do not redo file if the same exists! (save starting a new thread!)
        if [ -f ${NEWMODNAME} ] && [ -f ${NEWMODVOXNAME} ]; then
            echo 'Files already exists. Skipping...'
            continue
        fi

        # Start processing as a separate script
        {
        if [ ! -f ${NEWMODNAME} ]; then # Need to create a rotated model!
            meshlabserver -i ${m} -o ${NEWMODNAME} -s ${SCRIPTNAME} &> /dev/null
            if [ $? -ne 0 ]; then
                echo 'Last model conversion failed! for '${NEWMODNAME}
                exit 0
            fi
        fi

        if [ ! -f ${NEWMODVOXNAME} ]; then # Need to create a voxel map
            echo 'Voxelization... '$(basename ${m})
            # xvfb-run -s "-screen 0 640x480x24"
            ./binvox -rotx -rotx -rotz -aw -pb -e -d ${RES} ${NEWMODNAME} &> /dev/null
            echo 'Done voxelization'
            if [ $? -ne 0 ]; then
                echo 'Last model voxelisation failed! for '${NEWMODVOXNAME}
                exit 0
            fi
        fi
        } &

        # Manage parallel start nodes
        (( PARALLELJ ++ ))
        if [ ${PARALLELJ} -ge ${MAXPARALLELJOBS} ]; then
            echo 'Waiting for jobs ...'
            wait
            PARALLELJ=0
        fi
    done
    echo 'Finished for angle: '${x}'/'${y}'/'${z}
    MODELID=0
done
wait
echo 'Done conversion and voxelization'

# Convert voxels to hdf5
# python store2hdf5.py
# echo 'Done storing to db!'
# echo 'Open to visualize!'
