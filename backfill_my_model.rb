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

wal_threshold = 0.0787402.to_l # 2mm = 0.0787402inch

mod = Sketchup.active_model # Open model
ent = mod.entities # All entities in model
sel = mod.selection # Current selection

    # Verify selection
if mod.selection.empty?
    UI.messagebox('No Groups or Components selected.')
    return
end

sel_group = sel[0]
sel_size = sel_group.bounds.max # Get the first selected group
sel_group_ent = sel_group.entities

#puts sel_size

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

mod.commit_operation

