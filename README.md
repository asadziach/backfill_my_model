![space app logo](https://2016.spaceappschallenge.org/static/assets/4375bcd4e22d6ba223d9993eac66ffa1.svg "space apps")

# Backfill My Model

My solution to NASA 2016 Space Apps Challenge. 

Link https://2016.spaceappschallenge.org/challenges/tech/backfill-my-model/projects/slice-and-dice

[![See it in action on youtube](http://img.youtube.com/vi/ECU3__ve1Do/0.jpg)](https://youtu.be/ECU3__ve1Do)

It is prototype of a tool that will accept a very thin (scaled down), or "surface only" (tessellated model) and "fill in" behind the surface to a sufficient depth to allow printing on a 3-D printer.

- To use, open the 3D model in Sketchup Make 2016. It can take stl via a free plugin.

- Go to Window->Ruby console and paste the contents of backfill_my_model.rb. 

- Select and create a group of the model.

- Right click and select "Backfill My Model" option

- A dialog asks for the minimum wall thickness and the layer (slice) size. A smaller size is more accurate but takes longer to process. The processing time will also increase with more complex models.

- Optional color parameter will paint the faces added and changed for easy identification. Color value 'Default' disables it.

- It moves the model to origin and creates a disk. The disk is stepped up according to step size. It then calculates a series of thin horizontal slices through the selection's faces

- The intersection slices forms new edges. It calls 'find_faces' API on new edges. This creates new faces that will be used for analyzing thin walls.

### Known Issues

- Edges on some surfaces failed to form a face with the 'find_faces' above e.g see below. This will affect the thin wall detection (that depands on faces).

![known issues](https://i.imgsafe.org/83db15f.png "known issues")

- Sometimes the faces next to the thin walls gets incorrectly marked to be 'pulled'

- There are lot of printfs for debugging. This reduces execution speed.

- The selected group end up in 'exploded' state at the end of operation.
