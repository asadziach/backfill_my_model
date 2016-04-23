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

mod.start_operation("coloring faces")

puts wal_threshold
    # Do this for each face
sel_group_ent.each { |f|
    if f.typename == "Face"
        edges = f.edges  # for all edages of this face
         edges.each { |e|
            
            if e.length < wal_threshold
                 puts e.length 
                 
                f.material = [128,0,0]
            end
         }
    end
}

###

selected = sel[0]

###

# -------------- set up @units and @percent in def dialog for later...

# -------------- make cutting disc face at xy bounds

###

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



#### ------- slice & z inc ------------------------------

slice = @resolution.to_f * 0.0393701 ### convert mm to inches

increment_z = (zmax-zmin)/(((zmax-zmin)/slice).ceil)

###

apex = Geom.linear_combination(0.5,[xmin,ymin,zmax+2],0.5,[xmax,ymax,zmax+2])

### +2 puts it above top ( for text loc'n )

pnt1 = [xmin,ymin,zmin] 

pnt2 = [xmax,ymax,zmin] 

ctr = Geom.linear_combination(0.5,pnt1,0.5,pnt2)

rad = (pnt1.distance pnt2)### make a LOT bigger than bb ###v1.3

###

disc = ent.add_group

discentities = disc.entities

disccircle = BackFillModel.circle(ctr,[0,0,-1],rad,24)

discentities.add_face disccircle

###

#--------------------------- reset Z max and min's


zmin = zmin+(increment_z/ 2)

###

# ------------------------ do each of slice

vol=ent.add_group

volentities=vol.entities

vol.name="Volume-"+@sfix


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

for f in volentities

    if f.typename=="Face"    
        f.material=colour 

        area=(area+f.area) 

        edges = f.edges  # for all edages of this face
         edges.each { |e|
            
            if e.length < wal_threshold
                 puts e.length 
                 
                f.material = [128,0,0]
            end
         }
    end #if

end#for f

###

if area==0

   UI.beep

   UI.messagebox("There is NO Volume !")

   vol.erase! if vol.valid?

   return nil

end#if

# --------------- get volume ----


volume=(area*increment_z)### in cubic inches


# ---------------------- Close/commit group

mod.commit_operation

#-----------------------

puts volume

mod.start_operation("Cleanup Temp Geometry")

if UI.messagebox("Remove added gematry ?  ",MB_YESNO,"Cleanup Temp ?") == 6 ### 6=YES 7=NO
    for f in volentities

      f.erase!

    end#for f
end#if

# ---------------------- Close/commit group

mod.commit_operation

#-----------------------

end #BackFillModel::slice 

def BackFillModel::dialog

### get units and accuracy etc

   resolution = ["0.1", "0.2", "0.3", "0.4", "0.5"].join('|')

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
