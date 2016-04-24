#  Copyright 2016 Asad Zia

#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at

#       http://www.apache.org/licenses/LICENSE-2.0

#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
########################################################################
require 'set'
require 'sketchup.rb'

class BackFillModel


########################################################################
########################################################################
def BackFillModel::slice

if !BackFillModel.envCheck
    return false
end #if

# ----------- dialog ----------------

  return nil if not BackFillModel.dialog ### do dialog...

###

@sfix=Time::now.to_i.to_s[3..-1]
wal_threshold = (@min_wall_inch.to_f * 0.0393701 ) # inch to mm

mod = Sketchup.active_model # Open model
ent = mod.entities # All entities in model
sel = mod.selection # Current selection

sel_group = sel[0]
sel_size = sel_group.bounds.max # Get the first selected group
sel_group_ent = sel_group.entities



###

selected = sel[0]



# -------------- make cutting disc face at xy bounds

###


bb = selected.bounds

xmin = bb.min.x

ymin = bb.min.y

xmax = bb.max.x

ymax = bb.max.y

zmin = bb.min.z

zmax = bb.max.z

###

if xmin == xmax or ymin == ymax or zmin == zmax

   UI.beep

   UI.messagebox("The Selection has no Volume !")

   return nil

end#if

###
mod.start_operation("Move to origin")

trans = Geom::Transformation.new(bb.corner(0).vector_to(ORIGIN)) ;  # move the temp bounding box 

Sketchup.active_model.entities.transform_entities(trans, sel.to_a ) ; 

mod.commit_operation ; 

#### ------- slice & z inc ------------------------------

mod.start_operation("Volume Analysis")

slice = @resolution.to_f * 0.0393701 ### convert mm to inches

increment_z = (zmax-zmin)/(((zmax-zmin)/slice).ceil)

###

pnt1 = [xmin,ymin,zmin] 

pnt2 = [xmax,ymax,zmin] 

ctr = Geom.linear_combination(0.5,pnt1,0.5,pnt2)

rad = (pnt1.distance pnt2)### make a LOT bigger than bb 

###

disc = ent.add_group

discentities = disc.entities

disccircle = BackFillModel.circle(ctr,[0,0,-1],rad,24)

discentities.add_face disccircle

###

#--------------------------- reset Z min


zmin = zmin+(increment_z/ 2)

###

# ------------------------ do each of slice

vol= sel[0] 

volentities=vol.entities


### loop through all possible slices - bottom up

n = ((zmax-zmin)/slice).ceil

c = 0

z = increment_z/ 2 

while z < zmax-zmin+increment_z 

### do cut

  disc.move! Geom::Transformation.new [0,0,z] ### first placing near bottom 

  discentities.intersect_with true, disc.transformation, vol, vol.transformation, true, selected

  z = z+increment_z

  c = c+1

end#while

### delete disc

disc.erase!

### face the slices

for e in volentities

  e.find_faces if e.typename == "Edge"

end#for e

###

faces = []

for f in volentities

   if f.typename == "Face"

      faces = faces.push(f)

   end

end#for f

faces=faces.uniq

###

for face in faces

   face.reverse! if face.normal==[0,0,-1] ### now all face up

end#for face

### now work out which is which...

keptfaces = []

(faces.length-1).times do |this|

   for face in faces

    if face.valid?

      for edgeuse in face.outer_loop.edgeuses

         if not edgeuse.partners[0] ### outermost face

            keptfaces = keptfaces.push(face)

            faces = faces - [face]

            loops = face.loops

            for loop in loops

               for fac in faces

                  if fac.valid? and (fac.outer_loop.edges - loop.edges) == []

                     faces = faces - [fac]

                     fac.erase!### fac abutts kept face so it must be erased...

                  end #if fac

               end #for fac

            end #for loop

         end #if outermost

      end #for edgeuse

    end #if valid

   end #for face

end#times

### -------------- now find area of all edges etc

colour=@colour

colour=nil if colour=="<Default>"

area = 0

seg_to_pull = []

facecount = 0
edgecount = 0

planer_faces = []
for f in volentities

    if f.typename=="Face"

        if f.vertices.length == 4
            flat = false
            v = f.vertices

            print v[0].position.z
            print " "
            print v[1].position.z
            print " "
            print v[2].position.z
            print " "
            print v[3].position.z
            puts ""

            if (v[0].position.z == v[1].position.z) &&  (v[2].position.z == v[3].position.z ) && (v[1].position.z == v[2].position.z )
                flat = true if (v[0].position.z != bb.min.z) && ( v[0].position.z != bb.max.z)
            end

        end
        facecount = facecount +1 if flat
        planer_faces.push(f) if flat
    end
    if f.typename=="Edge"
        edgecount = edgecount +1
    end
end

print "faces "
print facecount
print " edges " 
print edgecount
puts ""
   
for f in planer_faces

#    if f.typename=="Face"    
        f.material=colour 

        area=(area+f.area) 

        edges = f.edges  # for all edages of this face

        pull_next = false
        for e in edges
            if pull_next
                pts = []
                pts[0] = e.vertices[0].position
                pts[1] = e.vertices[1].position
                seg_to_pull.push(pts) 
                pull_next = false
            end
            if e.length < wal_threshold
                pull_next = true 
                # TODO calculate the amount to backfill requied and bundle it
            end #if
        end #for
        if pull_next #if last one was short
            pts = []
            pts[0] = edges[0].vertices[0].position
            pts[1] = edges[0].vertices[1].position
            seg_to_pull.push(pts) 
            pull_next = false
        end
        
 #   end #if

end#for f

mod.commit_operation

if UI.messagebox("Remove added gematry ?  ",MB_YESNO,"Cleanup Temp ?") == 6 ### 6=YES 7=NO

    Sketchup.undo

end#if

mod.start_operation("Coloring")


sel_group.explode

external_faces = Set.new []

 # Do this for each face
mod.active_entities.each { |f|
    if f.typename == "Face"
        external_faces.add(f)
    end
}

faces_to_color = []

for virtex_pair in seg_to_pull
        point1 = virtex_pair[0]
        point2 = virtex_pair[1]
        print point1
        print " "
        print point2
        puts ""
end #for

external_faces.each { |f|
    for virtex_pair in seg_to_pull
            point1 = virtex_pair[0]
            point2 = virtex_pair[1]
            d1 = point1.distance_to_plane(f.plane) 
            d2 = point2.distance_to_plane(f.plane) 
            puts d1
            puts " "
            puts d2
            if (d1==0 && d2 == 0) # Sketchup seem to place them slightly off 
                faces_to_color.push(f)
                puts " ADDED"
            else
                puts " REJECTED"                
            end #if
    end #for
 }


for f in faces_to_color         
    f.material = colour
end #for

extrude_amount = 0.5 * 0.0393701; #TODO add backfill with the amount calculated earlier
for f in faces_to_color         
    f.pushpull(extrude_amount, false) 
end #for

###

if area==0

   UI.beep

   UI.messagebox("There is NO Volume, work in progress not all figures will work !")

   vol.erase! if vol.valid?

   return nil

end#if


# ---------------------- Close/commit group

mod.commit_operation

#-----------------------


end #BackFillModel::slice 

def BackFillModel::dialog

### get units and accuracy etc

   resolution = ["0.1", "0.2", "0.3", "0.4", "0.5", "10"].join('|')

   wall_thickness = ["0.5", "1.0", "1.5", "2", "2.5"].join('|')

   mcolours=Sketchup.active_model.materials

   colours=[]

   mcolours.each{|e|colours.push e.name}

   colours.sort!

   colours=colours+["<Default>"]+(Sketchup::Color.names.sort!)

   colours.uniq!

   colours=colours.join('|')

   prompts = ["Slice mm: ","Colour: ", "Min Wall Thickness mm"]

   title = "Paramters"

   @colour="<Default>" if not @colour

   values = [@resolution,@colour, @min_wall_inch]

   popups = [resolution,colours, wall_thickness]

   results = inputbox(prompts,values,popups,title)

   return nil if not results

### do processing of results

@resolution,@colour,@min_wall_inch=results

true

###

end #def BackFill::dialog

########################################################################
########################################################################
# --- Function for generating points on a circle
def BackFillModel::circle(center,normal,radius,numseg)
    # Get the x and y axes
    axes = Geom::Vector3d.new(normal).axes
    center = Geom::Point3d.new(center)
    xaxis = axes[0]
    yaxis = axes[1]
    xaxis.length = radius
    yaxis.length = radius
    # compute the points
    da = (Math::PI * 2) / numseg
    pts = []
    for i in 0...numseg do
        angle = i * da
        cosa = Math.cos(angle)
        sina = Math.sin(angle)
        vec = Geom::Vector3d.linear_combination(cosa,xaxis,sina,yaxis)
        pts.push(center + vec)
    end
    # close the circle
    pts.push(pts[0].clone)
    pts
end #def BackFillModel""circle

########################################################################
########################################################################
def BackFillModel::envCheck

if (Sketchup.version.split(".")[0].to_i<16)

     UI.beep

     UI.messagebox("Sorry. Only verified with Sketchup version 16.")

     return false

end#if

mod = Sketchup.active_model # Open model
ent = mod.entities # All entities in model
sel = mod.selection # Current selection

if sel.empty?

    UI.beep

    UI.messagebox("NO Selection !")

    return false

end #if

if sel[1]

    UI.beep

    UI.messagebox("Selection MUST be ONE Group or Component !")

    return false

end# if

if sel[0].typename != "Group" and sel[0].typename != "ComponentInstance"

    UI.beep

    UI.messagebox("Selection is NOT a Group or Component !")

    return false
end#if

return true

end #BackFill::envCheck

end #class BackFillModel

########################################################################
########################################################################
if( not file_loaded?("backfill_my_model.rb") )

add_separator_to_menu("Plugins")

UI.menu("Plugins").add_item("Back Fill My Model") {BackFillModel.slice }


   UI.add_context_menu_handler do | menu |

      if (Sketchup.active_model.selection[0].typename == "Group" or Sketchup.active_model.selection[0].typename == "ComponentInstance")

         menu.add_separator

         menu.add_item("Back Fill My Model") {BackFillModel.slice  }

      end #if ok

   end #do menu

end#if

file_loaded("backfill_my_model.rb")
