# model-net-converter
Tools for creating different views for the ModelNet object db.

The script works using the meshlab server to generate different scripts for editing the 3D models, rotate/edits them and uses the binvox tool to voxelize into their coresponding 3d voxels. 

It does the processing on batches of models, where each batch size is dependant on CPU thread count and processed in parallel. 
