
unit main;

{$mode objfpc}{$h+}

interface

uses
  msetypes, mseglob, mseguiglob, mseguiintf, mseapplication, msestat, msemenus,
  msegui, msegraphics, msegraphutils, mseevent, mseclasses, msewidgets, mseforms,
  msegrids, msebitmap, msedragglob, msestatfile, msegridsglob, msekeyboard,
  mserttistat, msedispwidgets, mserichstring;

const
  cellwidth = 40;
  cellheight = 40;

type
  piecekindty = (pk_none, pk_pawn, pk_knight, pk_bishop, pk_rook, pk_queen, pk_king);
  piececolorty = (pc_white, pc_black);

  cellstatety = (cs_black, cs_dragsource, cs_reject, cs_accept);
  cellstatesty = set of cellstatety;

  colty = (col_a, col_b, col_c, col_d, col_e, col_f, col_g, col_h);
  rowty = (row_1, row_2, row_3, row_4, row_5, row_6, row_7, row_8);

  cellty = record
    col: colty;
    row: rowty;
  end;

  celldataty = record
    piece: piecekindty;
    color: piececolorty;
    state: cellstatesty;
  end;

  cellsty = array[colty, rowty] of celldataty;
  boardstatety = (bs_keymoving);
  boardstatesty = set of boardstatety;

  boardty = record
    cells: cellsty;
    state: boardstatesty;
    dragpiece: celldataty;
    dragpos: pointty;
    movesource: cellty;
    movedest: cellty;
  end;
  pboardty = ^boardty;

  tchessoptions = class(toptions)
  private
    fwhiteboardtexture: filenamety;
    fblackboardtexture: filenamety;
    fnohatching: boolean;
    procedure setwhiteboardtexture(const avalue: filenamety);
    procedure setblackboardtexture(const avalue: filenamety);
    procedure setnochatching(const avalue: boolean);
  published
    property whiteboardtexture: filenamety read fwhiteboardtexture write setwhiteboardtexture;
    property blackboardtexture: filenamety read fblackboardtexture write setblackboardtexture;
    property nohatching: boolean read fnohatching write setnochatching;
  end;

  textureflagty = (tef_valid, tef_haswhiteboardtexture, tef_hasblackboardtexture, tef_nohatching);
  textureflagsty = set of textureflagty;

  tmainfo = class(tmainform)
    grid: tdrawgrid;
    pieceimages: timagelist;
    cellimages: timagelist;
    tmainmenu1: tmainmenu;
    concave: tfacecomp;
    tstatfile1: tstatfile;
    mainmenuframe: tframecomp;
    menuitemframe: tframecomp;
    convex: tfacecomp;
    trttistat1: trttistat;
    gamestatedisp: tstringdisp;
    procedure loadedev(const sender: TObject);
    procedure drawcellev(const sender: tcol; const canvas: tcanvas; var cellinfo: cellinfoty);
    procedure boardpaintev(const sender: twidget; const acanvas: tcanvas);
    procedure exitev(const sender: TObject);
    procedure resetev(const sender: TObject);
    procedure dragbeginev(const asender: TObject; const apos: pointty; var adragobject: tdragobject; var processed: boolean);
    procedure dragoverev(const asender: TObject; const apos: pointty; var adragobject: tdragobject; var accept: boolean; var processed: boolean);
    procedure dragdropev(const asender: TObject; const apos: pointty; var adragobject: tdragobject; var processed: boolean);
    procedure dragendev(const asender: TObject; const apos: pointty; var adragobject: tdragobject; const accepted: boolean; var processed: boolean);
    procedure cellev(const sender: TObject; var info: celleventinfoty);
    procedure textureev(const sender: TObject);
    procedure getoptionsobjectev(const sender: TObject; var aobject: TObject);
    procedure createev(const sender: TObject);
    procedure destroyev(const sender: TObject);
    procedure boardbeforepaintev(const sender: twidget; const acanvas: tcanvas);
  private
    fboard: boardty;
    function getcells(const acell: cellty): celldataty;
    procedure setcells(const acell: cellty; const avalue: celldataty);
    function getcellpiece(const acell: cellty): piecekindty;
    procedure setcellpiece(const acell: cellty; const avalue: piecekindty);
    function getcellcolor(const acell: cellty): piececolorty;
    procedure setcellcolor(const acell: cellty; const avalue: piececolorty);
    function getcellstate(const acell: cellty): cellstatesty;
    procedure setcellstate(const acell: cellty; const avalue: cellstatesty);
  protected
    ftextureflags: textureflagsty;
    procedure boardchanged();
    procedure texturechanged();
    procedure checktexture();
    procedure invalidateboardcell(const acell: cellty);
    function beginmove(const acoord: gridcoordty): boolean;
    procedure endmove();
    function setmovedest(const acoord: gridcoordty; const amove: boolean): boolean;
    function dragrect(): rectty;
    function cellbygridcoord(const gridcell: gridcoordty): celldataty;
    procedure drawcell(const acanvas: tcanvas; const apos: pointty; const acelldata: celldataty);
    procedure checkdrag(const adragobject: tdragobject; const apos: pointty; var accept: boolean; const amove: boolean);
    property cells[const acell: cellty]: celldataty read getcells write setcells;
    property cellpiece[const acell: cellty]: piecekindty read getcellpiece write setcellpiece;
    property cellcolor[const acell: cellty]: piececolorty read getcellcolor write setcellcolor;
    property cellstate[const acell: cellty]: cellstatesty read getcellstate write setcellstate;
  public
    chessoptions: tchessoptions;
  end;

var
  mainfo: tmainfo;

implementation

uses
  main_mfm, texturedialog, mseformatpngread, mseformatjpgread, mseeditglob,
  rules, log;

const
  pieceorder: array[colty] of piecekindty = (pk_rook, pk_knight, pk_bishop, pk_queen, pk_king, pk_bishop, pk_knight, pk_rook);

function gridcoordtocell(const acoord: gridcoordty): cellty;
begin
  result.col := colty(acoord.col);
  result.row := rowty(7 - acoord.row);
end;

function gridcoordtocell(const acoord: gridcoordty; out cell: cellty): boolean;
begin
  result := (acoord.col >= 0) and (acoord.row >= 0) and (acoord.col < 8) and (acoord.row < 8);
  if result then begin
    cell := gridcoordtocell(acoord);
  end;
end;

function celltogridcoord(const acell: cellty): gridcoordty;
begin
  result.col := ord(acell.col);
  result.row := 7 - ord(acell.row);
end;

function possiblylegalmove(const board: boardty; const source, dest: cellty): boolean;
begin
  result := (board.cells[dest.col, dest.row].piece = pk_none)
    or (board.cells[dest.col, dest.row].color <> board.cells[source.col, source.row].color);
(*
  Pour éliminer le roque à la façon des échecs 960 (où le roi prend la tour),
  que l'unité Rules accepterait, mais qui ne serait pas géré correctement par
  le programme dans son état actuel.
*)
end;

function piecemove(var board: boardty; const source, dest: cellty; const move: boolean): boolean; //returns true if allowed
var
  state1: cellstatesty;
begin
  //check chess rules here
  (*
  result := board.cells[dest.col, dest.row].piece = pk_none;
  *)
  result := possiblylegalmove(board, source, dest) and rules.IsMoveLegal(source, dest); (* Roland *)
  if result and move then
  begin
    if board.cells[source.col, source.row].piece = pk_king then (* Mouvement de roi *)
    begin
      if (source.col = col_e) and (dest.col = col_g) then (* e1g1, e8g8 *)
      begin
        state1 := board.cells[col_f, dest.row].state;
        board.cells[col_f, dest.row] := board.cells[col_h, source.row];
        board.cells[col_f, dest.row].state := state1; //restore
        board.cells[col_h, source.row].piece := pk_none;
      end else
      if (source.col = col_e) and (dest.col = col_c) then (* e1c1, e8c8 *)
      begin
        state1 := board.cells[col_d, dest.row].state;
        board.cells[col_d, dest.row] := board.cells[col_a, source.row];
        board.cells[col_d, dest.row].state := state1; //restore
        board.cells[col_a, source.row].piece := pk_none;
      end;
    end else
      if board.cells[source.col, source.row].piece = pk_pawn then (* Mouvement de pion *)
      begin
        if (board.cells[dest.col, dest.row].piece = pk_none) and (dest.col <> source.col) then (* Prise en passant *)
        begin
          board.cells[dest.col, source.row].piece := pk_none;
        end else
          if (dest.row = row_1) or (dest.row = row_8) then
          begin
            board.cells[source.col, source.row].piece := pk_queen;
          end;
      end;
    state1 := board.cells[dest.col, dest.row].state;
    board.cells[dest.col, dest.row] := board.cells[source.col, source.row];
    board.cells[dest.col, dest.row].state := state1; //restore
    board.cells[source.col, source.row].piece := pk_none;
    rules.DoMove(source, dest); (* Roland *)
  end;
end;

procedure boardenddrag(var board: boardty);
var
  c1: colty;
  r1: rowty;
begin
  with board do begin
    dragpiece.piece := pk_none;
    for c1 := low(c1) to high(c1) do begin
      for r1 := low(r1) to high(r1) do begin
        cells[c1, r1].state := cells[c1, r1].state - [cs_dragsource, cs_reject, cs_accept]; //remove drag states
      end;
    end;
    exclude(state, bs_keymoving);
  end;
end;

procedure boardinit(var board: boardty);
var
  c1: colty;
  r1: rowty;
begin
  fillchar(board, sizeof(board), 0);
  for c1 := low(colty) to high(colty) do begin
    with board.cells[c1, row_2] do begin
      piece := pk_pawn;
      color := pc_white;
    end;
    with board.cells[c1, row_1] do begin
      color := pc_white;
      piece := pieceorder[c1];
    end;
    with board.cells[c1, row_7] do begin
      piece := pk_pawn;
      color := pc_black;
    end;
    with board.cells[c1, row_8] do begin
      color := pc_black;
      piece := pieceorder[c1];
    end;
    if odd(ord(c1)) then begin
      for r1 := low(r1) to high(r1) do begin
        if odd(ord(r1)) then begin
          board.cells[c1, r1].state := [cs_black];
        end;
      end;
    end
    else begin
      for r1 := low(r1) to high(r1) do begin
        if not odd(ord(r1)) then begin
          board.cells[c1, r1].state := [cs_black];
        end;
      end;
    end;
  end;
end;

{ tmainfo }

procedure tmainfo.loadedev(const sender: TObject);
begin
  resetev(nil); //init board
  grid.fixcols.width := grid.fixrows[-1].height; //adjust to font height
end;

function tmainfo.getcells(const acell: cellty): celldataty;
begin
  result := fboard.cells[acell.col, acell.row];
end;

procedure tmainfo.setcells(const acell: cellty; const avalue: celldataty);
begin
  fboard.cells[acell.col, acell.row] := avalue;
  grid.invalidatecell(celltogridcoord(acell));
end;

function tmainfo.getcellpiece(const acell: cellty): piecekindty;
begin
  result := fboard.cells[acell.col, acell.row].piece;
end;

procedure tmainfo.setcellpiece(const acell: cellty; const avalue: piecekindty);
begin
  with fboard.cells[acell.col, acell.row] do begin
    if piece <> avalue then begin
      piece := avalue;
      invalidateboardcell(acell);
    end;
  end;
end;

function tmainfo.getcellcolor(const acell: cellty): piececolorty;
begin
  result := fboard.cells[acell.col, acell.row].color;
end;

procedure tmainfo.setcellcolor(const acell: cellty; const avalue: piececolorty);
begin
  with fboard.cells[acell.col, acell.row] do begin
    if color <> avalue then begin
      color := avalue;
      invalidateboardcell(acell);
    end;
  end;
end;

function tmainfo.getcellstate(const acell: cellty): cellstatesty;
begin
  result := fboard.cells[acell.col, acell.row].state;
end;

procedure tmainfo.setcellstate(const acell: cellty; const avalue: cellstatesty);
begin
  with fboard.cells[acell.col, acell.row] do begin
    if state <> avalue then begin
      state := avalue;
      invalidateboardcell(acell);
    end;
  end;
end;

procedure tmainfo.boardchanged();
begin
  grid.invalidate();
  gamestatedisp.Text := rules.GameStateMessage; (* Roland *)
end;

procedure tmainfo.texturechanged();
begin
  exclude(ftextureflags, tef_valid);
  boardchanged();
end;

procedure tmainfo.checktexture();
var
  bmp1, bmp2: tmaskedbitmap;
  i1, i2: int32;
begin
  if not (tef_valid in ftextureflags) then begin
    ftextureflags := [];
    if chessoptions.nohatching then begin
      include(ftextureflags, tef_nohatching);
    end;
    with grid.face.image do begin
      pos := grid.cellrect(makegridcoord(0, 0)).pos;
      clear();
      if chessoptions.whiteboardtexture <> '' then begin
        try
          loadfromfile(chessoptions.whiteboardtexture);
          include(ftextureflags, tef_haswhiteboardtexture);
        except
          //catch exceptions
        end;
      end;
    end;
    if chessoptions.blackboardtexture <> '' then begin
      bmp1 := tmaskedbitmap.create(bmk_rgb);
      bmp2 := tmaskedbitmap.create(bmk_rgb);
      try
        bmp1.loadfromfile(chessoptions.blackboardtexture);
        bmp2.size := makesize(8 * cellwidth, 8 * cellheight);
        bmp2.init(cl_white);
        bmp2.masked := true;
        bmp2.mask.init(cl_1); //all opaque
        for i1 := 0 to 7 do begin
          for i2 := 0 to 7 do begin
            if odd(i1) xor odd(i2) then begin
              bmp2.mask.canvas.fillrect(makerect(i1 * cellwidth, i2 * cellheight, cellwidth, cellheight), cl_0); //transparent fields
            end;
          end;
        end;
        with grid.face.image do begin
          if tef_haswhiteboardtexture in ftextureflags then begin
            paint(bmp2.canvas, makerect(nullpoint, bmp2.size), [al_tiled]); //get white background
          end;
          size := bmp2.size;
          kind := bmk_rgb;
          init(cl_white);
          if tef_haswhiteboardtexture in ftextureflags then begin
            bmp2.paint(canvas, nullpoint); //paint white fields
          end;
          bmp2.init(cl_white);
          bmp1.paint(bmp2.canvas, makerect(nullpoint, bmp2.size), [al_tiled]); //get black background
          bmp2.mask.canvas.rasterop := rop_not;
          bmp2.mask.canvas.fillrect(makerect(nullpoint, bmp2.size), 0); //invert field mask
          bmp2.paint(canvas, nullpoint); //paint black fields
        end;
        include(ftextureflags, tef_hasblackboardtexture);
      except
        //catch exceptions
      end;
      bmp1.destroy();
      bmp2.destroy();
    end;
    include(ftextureflags, tef_valid);
  end;
end;

procedure tmainfo.invalidateboardcell(const acell: cellty);
begin
  grid.invalidatecell(celltogridcoord(acell));
end;

function tmainfo.beginmove(const acoord: gridcoordty): boolean;
var
  cell1: cellty;
begin
  endmove(); //cancel current move
  result := gridcoordtocell(acoord, cell1);
  if result then begin
    result := cellpiece[cell1] <> pk_none;
    if result then begin
      fboard.movesource := cell1;
      fboard.movedest := cell1;
      cellstate[cell1] := cellstate[cell1] + [cs_dragsource];
    end;
  end;
end;

procedure tmainfo.endmove();
begin
  boardenddrag(fboard);
  exclude(fboard.state, bs_keymoving);
  grid.invalidate();
end;

function tmainfo.dragrect(): rectty;
begin
  if fboard.dragpiece.piece <> pk_none then begin
    result.x := fboard.dragpos.x - cellwidth div 2;
    result.y := fboard.dragpos.y - cellheight div 2;
    result.cx := cellwidth;
    result.cy := cellheight;
  end
  else begin
    result := nullrect;
  end;
end;

function tmainfo.cellbygridcoord(const gridcell: gridcoordty): celldataty;
begin
  result := fboard.cells[colty(gridcell.col), rowty(7 - gridcell.row)];
end;

procedure tmainfo.drawcell(const acanvas: tcanvas; const apos: pointty; const acelldata: celldataty);
begin
  with acelldata do begin
    if cs_dragsource in state then begin
      acanvas.fillrect(mr(0, 0, cellwidth, cellheight), cl_ltyellow);
    end
    else begin
      if cs_reject in state then begin
        acanvas.fillrect(mr(0, 0, cellwidth, cellheight), cl_ltred);
      end
      else begin
        if cs_accept in state then begin
          acanvas.fillrect(mr(0, 0, cellwidth, cellheight), cl_ltgreen);
        end;
      end;
    end;
    if not (tef_nohatching in ftextureflags) or (state * [cs_dragsource, cs_reject, cs_accept] <> []) then begin
      if cs_black in state then begin
        cellimages.paint(acanvas, 1, apos);
      end
      else begin
        cellimages.paint(acanvas, 0, apos);
      end;
    end;
    pieceimages.paint(acanvas, ord(piece) - 1, apos, cl_default, cl_default, cl_default, ord(color));
  end;
end;

procedure tmainfo.drawcellev(const sender: tcol; const canvas: tcanvas; var cellinfo: cellinfoty);
begin
  drawcell(canvas, nullpoint, cellbygridcoord(cellinfo.cell));
end;

procedure tmainfo.boardpaintev(const sender: twidget; const acanvas: tcanvas);
begin
  drawcell(acanvas, dragrect().pos, fboard.dragpiece);
end;

function tmainfo.setmovedest(const acoord: gridcoordty; const amove: boolean): boolean;
var
  cell1: cellty;
begin
  result := gridcoordtocell(acoord, cell1);
  if result then begin
    cellstate[fboard.movedest] := cellstate[fboard.movedest] - [cs_accept, cs_reject]; //reset old cell
    fboard.movedest := cell1;
    result := piecemove(fboard, fboard.movesource, fboard.movedest, amove);
    if result then begin
      cellstate[fboard.movedest] := cellstate[fboard.movedest] + [cs_accept];
      if amove then begin
        grid.focuscell(acoord);
      end;
    end
    else begin
      cellstate[fboard.movedest] := cellstate[fboard.movedest] + [cs_reject];
    end;
  end;
end;

procedure tmainfo.checkdrag(const adragobject: tdragobject; const apos: pointty; var accept: boolean; const amove: boolean);
begin
  grid.invalidaterect(dragrect()); //old pos
  fboard.dragpos := apos;
  grid.invalidaterect(dragrect()); //new pos
  accept := setmovedest(grid.cellatpos(fboard.dragpos), amove);
end;

procedure tmainfo.dragbeginev(const asender: TObject; const apos: pointty; var adragobject: tdragobject; var processed: boolean);
begin
  if beginmove(grid.cellatpos(apos)) then begin
    adragobject := tcelldragobject.create(grid, adragobject, apos);
    fboard.dragpiece := cells[fboard.movesource];
    fboard.dragpiece.state := [];
    fboard.dragpos := apos;
  end;
end;

procedure tmainfo.dragoverev(const asender: TObject; const apos: pointty; var adragobject: tdragobject; var accept: boolean; var processed: boolean);
begin
  checkdrag(adragobject, apos, accept, false);
end;

procedure tmainfo.dragdropev(const asender: TObject; const apos: pointty; var adragobject: tdragobject; var processed: boolean);
var
  b1: boolean;
begin
  b1 := true;
  checkdrag(adragobject, apos, b1, true);
  if b1 then
    gamestatedisp.Text := rules.GameStateMessage; (* Roland *)
end;

procedure tmainfo.dragendev(const asender: TObject; const apos: pointty; var adragobject: tdragobject; const accepted: boolean; var processed: boolean);
begin
  endmove();
end;

procedure tmainfo.resetev(const sender: TObject);
begin
  ResetGame;
  boardinit(fboard);
  boardchanged();
end;

procedure tmainfo.exitev(const sender: TObject);
begin
  application.terminate();
end;

procedure tmainfo.cellev(const sender: TObject; var info: celleventinfoty);
begin
  case info.eventkind of
    cek_keydown: begin
        with info.keyeventinfopo^ do begin
          if shiftstate * shiftstatesrepeatmask = [] then begin
            case key of
              key_escape: begin
                  endmove();
                end;
              key_return, key_space: begin
                  if bs_keymoving in fboard.state then begin
                    setmovedest(info.cell, true);
                    endmove();
                  end
                  else begin
                    if beginmove(info.cell) then begin
                      include(fboard.state, bs_keymoving);
                    end;
                  end;
                end;
            end;
          end;
        end;
      end;
    cek_enter: begin
        if bs_keymoving in fboard.state then begin
          setmovedest(info.cell, false);
        end;
      end;
  end;
end;

procedure tmainfo.textureev(const sender: TObject);
begin
  ttexturedialogfo.create(nil).show(ml_application);
end;

procedure tmainfo.getoptionsobjectev(const sender: TObject; var aobject: TObject);
begin
  aobject := chessoptions;
end;

procedure tmainfo.createev(const sender: TObject);
begin
  chessoptions := tchessoptions.create;
end;

procedure tmainfo.destroyev(const sender: TObject);
begin
  chessoptions.free();
end;

procedure tmainfo.boardbeforepaintev(const sender: twidget; const acanvas: tcanvas);
begin
  checktexture();
end;

{ tchessoptions }

procedure tchessoptions.setwhiteboardtexture(const avalue: filenamety);
begin
  fwhiteboardtexture := avalue;
  mainfo.texturechanged();
end;

procedure tchessoptions.setblackboardtexture(const avalue: filenamety);
begin
  fblackboardtexture := avalue;
  mainfo.texturechanged();
end;

procedure tchessoptions.setnochatching(const avalue: boolean);
begin
  fnohatching := avalue;
  mainfo.texturechanged();
end;

end.
