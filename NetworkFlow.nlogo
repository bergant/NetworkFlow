;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                ;;
;; Network flow model
;; v 0.2 2016-03-27
;;
;; URL: https://github.com/bergant/NetworkFlow
;;
;; Darko Bergant
;;                                                                ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

breed [outputs output]
breed [inputs input]
breed [processes process]

globals [
  
]


turtles-own [
  p-demand ; demand potential
  p-supply ; supply potential
  
  p-outputs ; output portfolio (demand diversity)
  p-inputs ; input portfolio (supply diversity)
  
  created ; creation time (tick)  
]

links-own [
  lp-demand ; demand potential
  lp-supply ; supply potential
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                 ;;
;; Setup Procedures
;;                                                 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
 ; ask patches [ set pcolor white ]

  ;colors and shapes
  set-default-shape inputs "circle"
  set-default-shape outputs "circle"
  set-default-shape processes "circle"
  set-default-shape links "curved"
  
   ; create nodes
  create-outputs total-outputs [ 
    set p-demand 1.0
    set p-inputs no-turtles
    set p-outputs turtle-set self
    set ycor max-pycor - 0.3 * t-size
    set xcor min-pxcor + ( who + 0.5 ) / total-outputs * ( max-pxcor - min-pxcor ) 
  ]
  create-inputs total-inputs [ 
    set p-supply 1.0
    set p-inputs turtle-set self
    set p-outputs no-turtles
    set ycor min-pycor + 0.3 * t-size
    set xcor min-pxcor + ( who - total-outputs + 0.5 ) / total-inputs * ( max-pxcor - min-pxcor ) 
  ]

  reset-ticks
  add-process-initial
  
  update-states

  layout
  
  tick
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                 ;;
;; Main Procedures
;;                                                 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to go
  ; try to create new processes
  repeat max ( list 1  ( new-processes-factor * (count processes)) ) [ add-process ] 

  ; update supply and demand type
  ; balance supply and demand amplitude
  update-states

  ; remove links without flow 
  ; and remove vertices without links  
  recycle-bin
  
  ; update info again
  update-states
  
  ;display
  layout

  tick
end



to add-process-initial
  create-processes 1
  [
    set color red
    set p-inputs no-turtles
    set p-outputs no-turtles
    create-links-to n-of  initial-links outputs
    create-links-from n-of initial-links  inputs
    set created 0
  ]
end


to add-process
  create-processes 1
  [
    set p-inputs no-turtles
    set p-outputs no-turtles
    ifelse random 2 = 0 [ add-input ][ add-output ]
    set created ticks
  ]
  
end


; New node by input branches
;         
;          Trunk
;           .
;          /   
;       [New]
;       .   .
;      /     \
; Branch1   Branch2
;
to add-input

  ; select the trunk... 
  let n min list 5 count other processes
  let trunc-candidates n-of n other processes
  let trunk max-one-of trunc-candidates [ count p-outputs ]
  
  ;... and 2 branches
  let branches n-of 2 ( turtle-set inputs other processes with 
    [ self != trunk 
      ; and count my-out-links < 5 
      and count p-outputs >= [count p-outputs] of trunk 
    ] 
  )
  
  let valid? true
  ask branches
  [
    ;Rule: trunk outputs should not be subset of branch outputs
    if BranchRule? and any? [p-outputs] of trunk and not member? trunk out-link-neighbors 
    [
      if is-subset? ( [p-outputs] of trunk ) p-outputs [ set valid? false stop ] 
    ]
  ]
  
  ; connect if valid branch or die
  ifelse valid?
  [ 
    create-link-to trunk
    create-links-from branches
  ]
  [
    die
  ]
  
end

; New node by output branches
;
; Branch1  Branch2
;    .       .
;     \     /
;      [New]
;        .   
;       /   
;    Trunk
;
to add-output
  ; create trunk ...
  let n min list 5 count other processes
  let trunc-candidates n-of n other processes
  let trunk max-one-of trunc-candidates [ count p-inputs ]

  ;... and 2 branches
  let branches n-of 2 ( turtle-set outputs other processes with 
    [ self != trunk 
      ;and count my-in-links < 5 
      and count p-inputs >=  [count p-inputs]  of trunk
    ] 
  )
  
  let valid? true
  ask branches
  [
    ;Rule: trunk inputs should not be subset of branch inpputs
    if BranchRule? and any? [p-inputs] of trunk and not member? trunk in-link-neighbors 
    [
      if is-subset? ( [p-inputs] of trunk ) p-inputs  [ set valid? false stop ]
    ]  
  ]
  
  ; connect if valid branch or die
  ifelse valid?
  [ 
    create-link-from trunk
    create-links-to branches
  ]
  [
    die
  ]  
end


; reports if turtle set A is sub turtle set of B
to-report is-subset? [ a b ]
  report count (turtle-set a b) <= count b
end


to recycle-bin
  ask turtles [ reduce-links ] 
  if count processes > 1 
  [
    ask processes [ reduce-node ]
  ]
end


to reduce-links
  ; remove the link if the link flaw is very low compared to the sum of all links of the node

  ; get the flow of all links from and to the node:
  let total-link-flow sum [ link-flow ] of ( link-set my-in-links my-out-links ) / 2
  if total-link-flow = 0 [stop]

  ; the link with min flow:
  let min-link min-one-of ( link-set my-in-links my-out-links ) [ link-flow ]
  if  min-link = nobody [ stop ]
  
  ; if the weak link is lower than link-balance * total flow:
  if [ link-flow ] of min-link / total-link-flow < link-balance [ ask min-link [ die ] ]
end


to reduce-node
  ; if the process node have no inputs or no outputs remove node
  if count my-in-links = 0 or count my-out-links = 0 [ die ]  
  
  ; if it is connected only to 1 output and 1 input remove
  ; the node and connect the input and output with direct link
  if count my-in-links = 1 and count my-out-links = 1 
  [
    let p-to [other-end] of one-of my-out-links
    let p-from [other-end] of one-of my-in-links
    if-else any? ( turtle-set p-to p-from ) with [ breed = processes ]
    [
      if p-from != p-to [ ask p-from [ create-link-to p-to ] ]
      die
    ]
    [
      die
    ]
  ]
end


to update-states
  clear-states
  repeat 15 
  [
    ask turtles 
    [ 
      read-from-neighbours 
      update-potential 
    ]
  ]
end
 
to clear-states
  ask processes [ set p-outputs no-turtles set p-inputs no-turtles set p-supply 0 set p-demand 0 ]
  ask outputs [ set p-inputs no-turtles set p-supply 0 ]
  ask inputs [ set p-outputs no-turtles set p-demand 0 ]
  ask links [ set lp-supply 0 set lp-demand 0 ]
end


to read-from-neighbours
  ; read total demand from my out-links and total supply potential from my in links
  ; update p-inputs, p-supply ( based on in-links p-inputs, lp-suppply )
  ; update p-outputs, p-demand ( based on out-links p-outputs, lp-demand )

  if breed != inputs and any? in-link-neighbors
  [
    set p-supply sum [ lp-supply ] of my-in-links
    set p-inputs turtle-set [p-inputs] of in-link-neighbors
  ]


  if breed != outputs and any? out-link-neighbors
  [
    set p-demand sum [ lp-demand ] of my-out-links
    set p-outputs turtle-set [p-outputs] of out-link-neighbors
  ]
  
end

to update-potential
    
  ; divide demand potential to in-links
  let count-in-links count my-in-links
  if-else p-supply > 0 and any? my-in-links and min [ lp-supply ] of my-in-links > 0
  [ ask my-in-links [ set lp-demand [p-demand / p-supply ] of myself * lp-supply ] ]
  [ ask my-in-links [ set lp-demand [p-demand / count-in-links ] of myself  ] ]
  
  ; divide supply potential to out-links
  let count-out-links count my-out-links
  if-else p-demand > 0 and any? my-out-links and  min [ lp-demand ] of my-out-links > 0
  [ ask my-out-links [ set lp-supply [p-supply / p-demand ] of myself * lp-demand ] ]
  [ ask my-out-links [ set lp-supply [p-supply / count-out-links ] of myself  ] ]
  
end


to-report link-flow
  report min ( list lp-supply lp-demand )
end


to-report node-flow
  report min ( list p-supply p-demand )
end

to-report node-comp
  report min ( list count p-outputs count p-inputs )
end

to-report flow-diversity
  ; overall diversity measure (h)
  report sum [ node-flow * count p-inputs / total-inputs ] of outputs
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                 ;;
;; Display                                         ;;
;;                                                 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; layout turtles and links
to layout
  ; set process node area to supply and brightness to last-trans
  ask turtles [ display-turtle ]
  display-links

  repeat 10 [
    layout-spring processes links spring-c spring-l repulsion-c
    if count inputs with [ any? out-link-neighbors ] >= 3 and count outputs with [ any? in-link-neighbors ] >= 3 [
      ask n-of 3 inputs with [ any? out-link-neighbors ] [ arange-inputs ]
      ask n-of 3 outputs with [ any? in-link-neighbors ] [ arange-outputs ]
    ]

    display
  ]
   
end


to-report node-rgb
    let ci count p-outputs
    let co count p-inputs
    let c1 ci / ( max list (co + ci) 1 ) * 255
    let c2 co / ( max list (ci + co) 1 ) * 255
    report (list c1 120 c2 )
end

to display-turtle
    
    let node_col node-rgb
    set color approximate-rgb item 0 node_col item 1 node_col item 2 node_col
    if breed = outputs [ set color blue - 1 ]
    if breed = inputs [ set color red - 1 ]
    
    set-opacity 0.80 
    set size ( sqrt ( min ( list p-demand p-supply ) ) / 2 + 0.3 ) * t-size
    ;set posx

    set label ""
    if show-labels2? [ 
      set label ( word round ( p-demand * 100 ) "/" round ( p-supply * 100 ) )    
    ]
    if show-labels3? [    
      let d-label 0
      let s-label 0

      ask p-outputs [ set d-label d-label + 10 ^ who ]
      let sd-label word d-label ""
      while [ length sd-label < count outputs ] [ set sd-label word "0" sd-label ]

      ask p-inputs [ set s-label s-label + 10 ^ ( who - count outputs )  ]
      let ss-label word s-label ""
      while [ length ss-label < count inputs ] [ set ss-label word "0" ss-label ]
      set label ( word sd-label "/" ss-label )
    ]


end

to display-links
  let max-link-flow 6
  if any? links [ set max-link-flow max [ link-flow ] of links ]
  if max-link-flow = 0 [ set max-link-flow  1 ]
  ask links 
  [
    if-else show-labels? 
    [ set label ( word round ( lp-demand * 100 ) "/" round ( lp-supply * 100 ) ) ]
    [ set label "" ]

   ; set color gray - 3
    set-opacity 0.30 + 0.70 * link-flow / max-link-flow
  ] 
end


to arange-inputs
  let node one-of other inputs with [ any? out-link-neighbors ]
  let parent one-of out-link-neighbors
  let node-parent [ one-of out-link-neighbors ] of node
  if parent = node-parent [ stop ]
  move-turtles self node parent node-parent
end

to arange-outputs
  let node one-of other outputs with [ any? in-link-neighbors ]
  let parent one-of in-link-neighbors
  let node-parent [ one-of in-link-neighbors ] of node
  if parent = node-parent [ stop ]
  move-turtles self node parent node-parent
end

to move-turtles [ n1 n2 p1 p2 ]
  let d1 [ xcor ] of n1 -[ xcor ] of n2
  let d2 [ xcor ] of p1 -[ xcor ] of p2
  if d1 * d2 < 0 
  [
    let xcor-temp [ xcor ] of n1
    ask n1 [ set xcor [ xcor ] of n2 ]
    ask n2 [ set xcor xcor-temp ]
  ]
  
end

; from http://complexityblog.com/blog/index.php?itemid=65
to set-opacity [ opacity ] ; 0..100
  ifelse is-list? color
    [ set color lput ( opacity * 255 ) sublist color 0 3 ]
    [ set color lput ( opacity * 255 ) extract-rgb color ]
end
@#$#@#$#@
GRAPHICS-WINDOW
204
10
752
579
20
20
13.122
1
12
1
1
1
0
0
0
1
-20
20
-20
20
1
1
1
ticks
30.0

BUTTON
11
18
75
51
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
11
59
76
92
Go once
go
NIL
1
T
OBSERVER
NIL
G
NIL
NIL
0

BUTTON
1124
484
1185
518
Layout
layout
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
80
18
143
51
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
12
115
189
148
total-outputs
total-outputs
1
64
32
1
1
NIL
HORIZONTAL

SLIDER
11
157
188
190
total-inputs
total-inputs
1
64
32
1
1
NIL
HORIZONTAL

PLOT
819
10
1192
160
System flow
tick
flow
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"M" 1.0 2 -7500403 true "" "plot count outputs"
"f" 1.0 0 -13791810 true "" "plot sum [ node-flow ] of outputs"
"h" 1.0 0 -11881837 true "" "plot flow-diversity"

SLIDER
10
209
187
242
initial-links
initial-links
0
30
3
1
1
NIL
HORIZONTAL

SWITCH
824
558
950
591
show-labels?
show-labels?
1
1
-1000

PLOT
820
341
995
471
Link flow histogram
flow
number of links
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "set-plot-x-range 0 count outputs / 2\nset-histogram-num-bars count outputs / 4 + 1\nhistogram [ min (list lp-demand lp-supply) ] of links"

PLOT
997
341
1186
471
log-log node flow
flow
number of nodes
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 2 -16777216 true "" "let max-degree total-outputs\n;; for this plot, the axes are logarithmic, so we can't\n;; use \"histogram-from\"; we have to plot the points\n;; ourselves one at a time\nplot-pen-reset  ;; erase what we plotted before\n;; the way we create the network there is never a zero degree node,\n;; so start plotting at degree one\nlet degree 1\nlet step 2\nwhile [degree <= max-degree * step] [\n  let matches turtles with [ node-flow > degree and node-flow <= degree * step]\n  if any? matches\n    [ plotxy log degree 2\n             log (count matches) 2 ]\n  set degree degree * step\n]"

SWITCH
824
595
956
628
show-labels2?
show-labels2?
1
1
-1000

BUTTON
12
420
112
453
Add process
add-process\ndisplay
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
122
420
194
453
Update
repeat 10 [ update-states ]\nlayout
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
53
478
147
511
Recycle Bin
recycle-bin\nlayout
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1125
527
1228
560
Layout circle
layout-radial turtles links ( max-one-of processes [ min ( list count p-outputs count p-inputs ) ]  )
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
10
249
187
282
link-balance
link-balance
0
0.5
0.2
0.02
1
NIL
HORIZONTAL

INPUTBOX
820
486
892
546
spring-c
0.2
1
0
Number

INPUTBOX
894
487
948
547
spring-l
1
1
0
Number

INPUTBOX
952
486
1029
546
repulsion-c
1
1
0
Number

INPUTBOX
1054
485
1110
545
t-size
1.1
1
0
Number

SWITCH
962
593
1095
626
show-labels3?
show-labels3?
1
1
-1000

SWITCH
10
295
134
328
BranchRule?
BranchRule?
0
1
-1000

MONITOR
1191
338
1270
383
Median links
median [ count my-in-links + count my-out-links] of processes
1
1
11

PLOT
820
170
1229
325
System complexity
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Processes" 1.0 0 -13791810 true "" "plot count processes"
"Links" 1.0 0 -11085214 true "" "plot count links"
"2 * processes" 1.0 0 -4539718 true "" "plot 2 * count processes"
"2 * (ins + outs)" 1.0 0 -1513240 true "" "plot 2 * (count inputs + count outputs)"

BUTTON
1125
572
1226
605
ImportWorld
import-world \"../Exportworld.csv\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1211
114
1268
159
Flow
flow-diversity
1
1
11

MONITOR
1274
339
1337
384
Max links
max [ count my-in-links + count my-out-links] of processes
1
1
11

SLIDER
10
339
182
372
new-processes-factor
new-processes-factor
0.1
1
0.25
0.05
1
NIL
HORIZONTAL

BUTTON
1127
613
1228
646
ExportWorld
export-world \"../Exportworld.csv\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
# Network Flow Model

## WHAT IS IT?

The model shows self-organisation of network structure, optimising flow from fixed diverse inputs to fixed diverse outputs.


## HOW IT WORKS

### Open System	
Model simulates a distribution of demand and supply to intermediate network nodes based on system inputs and outputs. Inputs represent fixed diverse supply and outputs represent fixed diverse demand.

### Network Structure	
Intermediate nodes are connected to each other as inputs and outputs. Each node represents a demand to his input nodes and supply to his output nodes. Each node is also an information source to other nodes – current demand level is sensed from output nodes and supply level is sensed from input nodes.

### Dynamic System 	
The network structure is self-designed and based on the decisions of individual vertices. The connection between two vertices is kept only if there is enough flow between the vertices which share the connection. New vertices are born periodically and they survive only if they carry enough flow. Flow is defined as the least of supply and demand.	

### Bounded Information	
Each node can only use the information available at his neighbour nodes. Also there is a maximum number of connections each node can handle. But there is no quantitative restrictions on flow (on nodes nor connections).	

### Diversity 
Each input node represent unique supply (good or service) and each output node represent special demand. The model defines each system input as a unit vector in N-dimensional space (if there are N inputs). In English: in case of 4 input nodes they would be defined as 1000, 0100, 0010 and 0001. Same with outputs. Merging two different inputs in some intermediate node would result in a combination of different types of flows (e.g. 1100 or 1010). 	


## HOW TO USE IT

Parameters:

- Set the number of inputs and outputs (from 20 to 60 should be OK)

- Set the number of initial links (3 is enough to start with)

- Link balance is the threshold for killing links with less flow then a percentage of node flow. With 0.2 you can expect around 2 or 3 links per node.

- new-processes-factor defines how many new nodes will model try to add at each iteration (number of nodes * factor)

Use **Setup** to apply your parameters and start with **Go**.

## THINGS TO NOTICE

Usually nodes get organised in a double-tree hierarchical structure.


## THINGS TO TRY

Try to change link-balance parameter and observe the speed of convergence and structure shape.

If you switch off the branch rule, the system can't find the path to organized structure. Branch rule prohibits cycles in the structure for new nodes and connections.



## CREDITS AND REFERENCES

Darko Bergant, Network Flow, (2015), GitHub repository, https://github.com/bergant/NetworkFlow


This work is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License](http://creativecommons.org/licenses/by-nc-sa/3.0/)

@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

curved
0.2
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
