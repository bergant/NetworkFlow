;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                ;;
;; Network flow model
;;                                                                ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

breed [outputs output]
breed [inputs input]
breed [processes process]

globals [
  info-updated?
]

turtles-own [
  p-demand ; demand potential
  p-supply ; supply potential
  
  p-outputs ; output portfolio
  p-inputs ; input portfolio
  
  tree-level ; just for analytical purposes
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
  set info-updated? false
 ; ask patches [ set pcolor white ]

  ;colors and shapes
  set-default-shape inputs "circle"
  set-default-shape outputs "circle"
  set-default-shape processes "circle"
  set-default-shape links "curved"
  
   ; create nodes
  create-outputs total-outputs [ 
    set ycor max-pycor 
    set xcor min-pxcor + ( who + 0.5 ) / total-outputs * ( max-pxcor - min-pxcor ) 
    set p-demand 1.0
    set p-inputs no-turtles
    set p-outputs turtle-set self
  ]
  create-inputs total-inputs [ 
    set ycor min-pycor 
    set xcor min-pxcor + ( who - total-outputs + 0.5 ) / total-inputs * ( max-pxcor - min-pxcor ) 
    set p-supply 1.0
    set p-inputs turtle-set self
    set p-outputs no-turtles
  ]

  add-process-initial
  update-states

  layout
  
  reset-ticks
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                 ;;
;; Main Procedures
;;                                                 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to go
  ; try to create a new activity
  add-process
  if count processes > 5 [ add-process ]

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
  ]
end


to add-process
  create-processes 1
  [
    set p-inputs no-turtles
    set p-outputs no-turtles
    ifelse random 2 = 0 [ add-input ][ add-output ]
  ]
  
end



;         
;          Trunk
;          /   
;       [New]   
;      /     \
;Branch1   Branch2
;

to add-input
 
  ; select the trunk and 2 branches
  let max-output max [ count p-outputs ] of inputs
  let trunk-candidates other processes with [ count p-outputs >= max-output ]
  
  ;let trunk-candidates other processes with [ count p-inputs <= count p-outputs ]
  if not any? trunk-candidates [stop]
  
  
  ;let trunk one-of ( turtle-set outputs other processes )
  ;let trunk one-of ( turtle-set outputs other trunk-candidates  )
  let trunk one-of other trunk-candidates
  let branches n-of 2 ( turtle-set inputs other trunk-candidates with [ self != trunk and count my-out-links < 5 ] )

  ; read compoments from branches and trunck (without branches if in intersection)
  let b-components turtle-set [ p-inputs ] of branches
  let t-components turtle-set [ p-inputs ] of 
    ( turtle-set [ in-link-neighbors ] of trunk ) with [ not member? self branches ]

  
  let valid? true
  ; Rule #1: branch components must not cover all trunk components 
  if is-subset? t-components b-components [ set valid? false die ]
  
  ask branches
  [
    ;Rule #2 trunk components must not cover all the branch components
    if is-subset? p-inputs t-components [ set valid? false stop]
    
    ;Rule #3 nasprotna komponenta izbrane veje ne sme pokrivati nasprotnih komponent trunka (razen če je že veja)
    if not member? trunk out-link-neighbors and any? [p-outputs] of trunk 
    [ if is-subset? ( [p-outputs] of trunk ) p-outputs  [ set valid? false stop ] ]

  ]
  
  ; connect if valid branch or die
  ifelse valid?
  [ 
    ; clear existing links from trunk to branches
    ask branches [ ask my-out-links with [ other-end = trunk ] [  die ] ]
    ; create links to trunk and from branches
    create-link-to trunk
    create-links-from branches
    set info-updated? false
  ]
  [
    ;show "invalid input proposal"
    die
  ]
  
end

;
; Branch1  Branch2
;     \     /
;      [New]   
;       /   
;    Trunk
;
to add-output 
  ; select the trunk and 2 branches
  let max-input max [ count p-inputs ] of outputs
  let trunk-candidates other processes with [ count p-inputs >= max-input ]  

  if not any? trunk-candidates [stop]
  
;  let trunk one-of ( turtle-set inputs other trunk-candidates ) 
  let trunk one-of other trunk-candidates
  let branches n-of 2 ( turtle-set outputs other trunk-candidates with [ self != trunk  and count my-in-links < 5 ] )

  ; read compoments from branches and trunck (without branches if in intersection)
  let b-components turtle-set [ p-outputs ] of branches
  let t-components turtle-set [ p-outputs ] of 
    ( turtle-set [ out-link-neighbors ] of trunk ) with [ not member? self branches ]
  
  let valid? true
  ; Rule #1: branch components must not cover all trunk components 
  if is-subset? t-components b-components [ set valid? false die ]
  
  ask branches
  [
    ;Rule #2 trunk components must not cover all the branch components
    if is-subset? p-outputs t-components [ set valid? false stop]

    ;Rule #3 nasprotna komponenta izbrane veje ne sme pokrivati nasprotnih komponent trunka (razen če je že veja) 
    ; inputi veje   
    if not member? trunk in-link-neighbors and any? [p-inputs] of trunk
    [ if is-subset? ( [p-inputs] of trunk ) p-inputs  [ set valid? false  stop ] ]
  
  ]
  
  ; connect if valid branch or die
  ifelse valid?
  [ 
    ; clear existing links from trunk to branches
    ask branches [ ask my-in-links with [ other-end = trunk ] [ die ] ]
    ; create links to trunk and from branches
    create-link-from trunk
    create-links-to branches
    set info-updated? false
  ]
  [
    ;show "invalid input proposal"
    die
  ]  
end


; reports if turtle set A is sub turtle set of B
to-report is-subset? [ a b ]
  report count (turtle-set a b) <= count b
end



to recycle-bin
  ask processes [ balance-links ] 
  ask processes [ reduce-node ]
end


to balance-links
  let total-link-flow sum [ link-flow ] of ( link-set my-in-links my-out-links ) / 2
  let min-link min-one-of ( link-set my-in-links my-out-links ) [ link-flow ]
  if  min-link = nobody [ stop ]
  if total-link-flow != 0 
  [
    if [ link-flow ] of min-link / total-link-flow < link-balance [ ask min-link [ die ] set info-updated? false ]
  ]
end

to balance-links-old
  let min-link min-one-of ( link-set my-in-links my-out-links ) [ link-flow ]
  let max-link max-one-of ( link-set my-in-links my-out-links ) [ link-flow ]
  if  min-link = nobody or max-link = nobody [ stop ]
  
  if [ link-flow ] of max-link != 0 
  [
    if [ link-flow ] of min-link / [ link-flow ] of max-link < link-balance [ ask min-link [ die ] set info-updated? false]
  ]
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

to reduce-node
  if count my-in-links = 0 or count my-out-links = 0 [ die ]  
  
  if count my-in-links = 1 and count my-out-links = 1
  [
    let p-to [other-end] of one-of my-out-links
    let p-from [other-end] of one-of my-in-links
    if-else any? ( turtle-set p-to p-from ) with [ breed = processes ]
    [
      if p-from != p-to [ ask p-from [ create-link-to p-to ] ]
      set info-updated? false
      die
    ]
    [
      ;show self
      set info-updated? false
      die
    ]
  ]
end


to update-states
  ;if not info-updated?
  ;[
    clear-states
    repeat 15 
    [
      ask turtles 
      [ 
        read-from-neighbours 
        update-potential 
      ]
    ]
    set info-updated? true
  ;]
end

to clear-states
  ask processes [ set p-outputs no-turtles set p-inputs no-turtles set p-supply 0 set p-demand 0 set tree-level 0]
  ask outputs [ set p-inputs no-turtles set p-supply 0 set tree-level 0]
  ask inputs [ set p-outputs no-turtles set p-demand 0 set tree-level 1]
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
    set tree-level max [ tree-level ] of in-link-neighbors + 1
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

  
  ;let theone max-one-of processes [ min ( list p-supply p-demand ) ]
  repeat 10 [
    layout-spring processes links 0.5 2 5
    ask n-of 3 inputs with [ any? out-link-neighbors ] [ arange-inputs ]
    ask n-of 3 outputs with [ any? in-link-neighbors ] [ arange-outputs ]
      ;layout-tutte (processes) links max-pxcor
      
    ;layout-radial processes links ( max-one-of processes [ min ( list count p-outputs count p-inputs ) ]  )
    display
  ]
  
end




to display-turtle
    
    let ci count p-outputs
    let co count p-inputs
    ;show ci
    let c1 ci / (ci + co) * 255
    let c2 co / (ci + co) * 255
    set color approximate-rgb c1 120 c2 
    if breed = outputs [ set color blue - 1 ]
    if breed = inputs [ set color red - 1 ]
    
    set-opacity 0.80 
    set size sqrt ( min ( list p-demand p-supply ) ) / 2 + 0.3

    if-else show-labels2? 
    [ set label ( word round ( p-demand * 100 ) "/" round ( p-supply * 100 ) )    ]
    [ set label "" ]

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


to export-graph
  carefully [ file-delete "edges.csv" ] []
  file-open "edges.csv"  ;; Opening file for writing
  ask links
  [ 
    ask both-ends with [ member? myself my-out-links ] [ file-type (word who ";")   ]
    ask both-ends with [ member? myself my-in-links ] [ file-type (word who ";")  ]
    file-print (word self ";" round ( lp-demand * 100 ) ";" round ( lp-supply * 100 ) ) 
  ]
  file-close  
  carefully [ file-delete "vertices.csv" ] []
  file-open "vertices.csv"  ;; Opening file for writing
  ask turtles
  [ 
    file-print (word ";" who ";" breed ";" round( p-demand * 100 ) ";" round( p-supply * 100)  ";" count p-outputs ";" count  p-inputs ";" ) 
  ]
  file-close  
  
end

to movie
  
  setup
  movie-start "out.mov"
  movie-grab-view ;; show the initial state
  repeat 30
  [ go
    movie-grab-view ]
  movie-close

end
@#$#@#$#@
GRAPHICS-WINDOW
234
10
780
577
20
20
13.0732
1
10
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
38
75
71
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
79
76
112
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
1

BUTTON
85
78
146
112
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

MONITOR
891
168
947
213
links
count links
0
1
11

BUTTON
80
38
143
71
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
1

SLIDER
10
162
187
195
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
9
204
186
237
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
Last output
tick
count
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Total output" 1.0 0 -7500403 true "" "plot sum [ min ( list p-demand p-supply ) ] of outputs"
"Market limit" 1.0 2 -10899396 true "" "plot count outputs"
"Diversity on output" 1.0 0 -2674135 true "" "plot sum [ min ( list p-demand p-supply ) * count p-inputs / total-inputs ] of outputs"

SLIDER
9
250
187
283
initial-links
initial-links
0
30
4
1
1
NIL
HORIZONTAL

SWITCH
8
309
134
342
show-labels?
show-labels?
1
1
-1000

MONITOR
819
168
888
213
processes
count processes
17
1
11

PLOT
819
220
994
340
Links
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "set-plot-x-range 1 25\nset-histogram-num-bars 25\nhistogram [ max( list count my-in-links count my-out-links )] of processes"

PLOT
997
220
1187
340
Component level
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "set-plot-x-range 0 count inputs\nset-histogram-num-bars count inputs\nhistogram [min (list count p-inputs count p-outputs)] of processes"

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
node flow
fitness
number of nodes
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 2 -16777216 true "" "let max-degree max [ node-flow ] of turtles\n;; for this plot, the axes are logarithmic, so we can't\n;; use \"histogram-from\"; we have to plot the points\n;; ourselves one at a time\nplot-pen-reset  ;; erase what we plotted before\n;; the way we create the network there is never a zero degree node,\n;; so start plotting at degree one\nlet degree 1\nlet step 1.5\nwhile [degree <= max-degree] [\n  let matches turtles with [ node-flow > degree and node-flow <= degree * step]\n  if any? matches\n    [ plotxy log degree 2\n             log (count matches) 2 ]\n  set degree degree * step\n]"

SWITCH
8
346
140
379
show-labels2?
show-labels2?
1
1
-1000

BUTTON
11
410
111
443
Add process
add-process
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
121
410
193
443
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
52
468
146
501
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
783
540
886
573
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

MONITOR
951
168
1040
213
Average
sum [ count p-inputs ] of outputs /  count outputs
2
1
11

MONITOR
1046
168
1120
213
Median out
median [ count p-inputs ] of outputs
17
1
11

SLIDER
192
252
225
402
link-balance
link-balance
0
0.5
0.2
0.02
1
NIL
VERTICAL

MONITOR
1125
168
1213
213
Completed
count outputs with [ count p-inputs = count inputs ]
3
1
11

MONITOR
1224
173
1281
218
Flow
max [ link-flow ] of links
17
1
11

MONITOR
1204
232
1261
277
Tree
max [ tree-level ] of turtles
17
1
11

MONITOR
1198
281
1279
326
Median Tree
median [tree-level] of outputs with [ tree-level > 0 ]
1
1
11

@#$#@#$#@
## WHAT IS IT?

This is a model of process network formation.

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
NetLogo 5.1.0
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
