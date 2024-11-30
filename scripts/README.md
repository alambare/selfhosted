# Update photos and videos

> This script requires all the photos of each album to be collocated in the same folder.

This script does the following:

- Rename invalid PNG to JPG
- Generate metadata sidecar files for '-edited' assets
- Rename metadata files ending in the like of .jpg(1).json to (1).jpg.json
- Adding missing created datetime for photos and videos (MP4, MOV)

```shell
# update all assets from ./lambare-aubin

./process.bash ../lambare-aubin
```
