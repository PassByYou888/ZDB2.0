unit ZDB2CoreTestFrm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Objects, FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo,
  FMX.Layouts, FMX.StdCtrls, FMX.Edit,

  CoreClasses, PascalStrings, DoStatusIO, UnicodeMixedLib, MemoryStream64, CoreCipher,
  zDrawEngine, zDrawEngineInterface_SlowFMX, Geometry2DUnit, zExpression,
  ZDB2_Core, ZDB2, ZIOThread, FMX.Memo.Types;

type
  TZDB2CoreTestForm = class(TForm)
    Memo: TMemo;
    pb: TPaintBox;
    Timer1: TTimer;
    Layout1: TLayout;
    Label1: TLabel;
    Edit1: TEdit;
    EditButton1: TEditButton;
    EditButton2: TEditButton;
    Button1: TButton;
    Layout2: TLayout;
    Label2: TLabel;
    Edit2: TEdit;
    EditButton3: TEditButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure EditButton1Click(Sender: TObject);
    procedure EditButton2Click(Sender: TObject);
    procedure EditButton3Click(Sender: TObject);
    procedure pbMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure pbPaint(Sender: TObject; Canvas: TCanvas);
    procedure Timer1Timer(Sender: TObject);
  private
    procedure DoStatus_Bcakcall(Text_: SystemString; const ID: Integer);
  public
    ZDBMem: TStream64;
    ZDB: TZDB2;
    dIntf: TDrawEngineInterface_FMX;
    mouse_pt: TVec2;
    PostThreadPool: TPost_ThreadPool;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  ZDB2CoreTestForm: TZDB2CoreTestForm;

implementation

{$R *.fmx}


constructor TZDB2CoreTestForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  AddDoStatusHook(Self, DoStatus_Bcakcall);
  ZDB := TZDB2.Create;
  dIntf := TDrawEngineInterface_FMX.Create;

  ZDBMem := TStream64.Create;
  ZDB.NewStream(ZDBMem, 1024 * 1024 * 128, 4 * 1024, TZDB2_SpaceMode.smBigData);
  DoStatus('New DB Done. size:%s physics block:%d', [umlSizeToStr(ZDB.Space.Space_IOHnd^.Size).Text, ZDB.Space.BlockCount]);
  PostThreadPool := TPost_ThreadPool.Create(4);
end;

destructor TZDB2CoreTestForm.Destroy;
begin
  DisposeObject(PostThreadPool);
  DisposeObject(dIntf);
  DisposeObject(ZDB);
  DisposeObject(ZDBMem);
  DeleteDoStatusHook(Self);
  inherited Destroy;
end;

procedure TZDB2CoreTestForm.Button1Click(Sender: TObject);
begin
  TCompute.RunP_NP(procedure
    var
      ID: TZDB2_BlockHndle;
      i, n: Integer;
    begin
      ZDB.WaitQueue;
      ID := ZDB.GetIndex;
      n := 1;
      for i in ID do
        begin
          DoStatusNoLn('%d' + #9, [i]);
          inc(n);
          if n >= 10 then
            begin
              DoStatusNoLn(#13#10);
              n := 0;
            end;
        end;
      DoStatusNoLn();
    end);
end;

procedure TZDB2CoreTestForm.Button2Click(Sender: TObject);
begin
  ZDBMem.Clear;
  ZDB.Free;
  ZDB := TZDB2.Create;
  ZDB.NewStream(ZDBMem, 1024 * 1024 * 128, 4 * 1024, TZDB2_SpaceMode.smBigData);
  DoStatus('New DB Done. size:%s physics block:%d', [umlSizeToStr(ZDB.Space.Space_IOHnd^.Size).Text, ZDB.Space.BlockCount]);
end;

procedure TZDB2CoreTestForm.Button3Click(Sender: TObject);
begin
  ZDB.TraversalP(False, False, nil, procedure(Sender: TZDB2; Traversal: TZDB2_Traversal; Mem: TZDB2_Mem; var Running: Boolean)
    var
      n: TZDB2_Mem;
    begin
      n := TZDB2_Mem.Create;
      n.NewParam(Mem);
      Mem.DiscardMemory;
      // 这里会把数据分配到线程池去解析处理
      PostThreadPool.MinLoad_Thread.PostP3(nil, n, Traversal.Current, procedure(Data1: Pointer; Data2: TCoreClassObject; Data3: Variant)
        begin
          DoStatus('条目:%d md5:%s crc32:%8x', [Integer(Data3), umlMD5String(TZDB2_Mem(Data2).Memory, TZDB2_Mem(Data2).Size).UpperText,
            umlCRC32(TZDB2_Mem(Data2).Memory, TZDB2_Mem(Data2).Size)]);
          DisposeObject(Data2);
        end);
    end, nil);
end;

procedure TZDB2CoreTestForm.Button4Click(Sender: TObject);
begin
  ZDB.Save(False);
end;

procedure TZDB2CoreTestForm.DoStatus_Bcakcall(Text_: SystemString; const ID: Integer);
begin
  Memo.Lines.Add(Text_);
  Memo.GoToTextEnd;
end;

procedure TZDB2CoreTestForm.EditButton1Click(Sender: TObject);
var
  Mem: TZDB2_Mem;
begin
  Mem := TZDB2_Mem.Create;
  Mem.Size := EStrToInt(Edit1.Text, 1024);
  ZDB.PostP(Mem, True, nil, procedure(Sender: TZDB2; UserData: Pointer; ID: Integer; Successed: Boolean)
    begin
      if Successed then
          DoStatus('写入成功 ID:%d size:%d', [ID, Sender.Space.GetDataSize(Sender.Space.BlockBuffer[ID].ID)]);
    end);
end;

procedure TZDB2CoreTestForm.EditButton2Click(Sender: TObject);
var
  Mem: TZDB2_Mem;
begin
  Mem := TZDB2_Mem.Create;
  Mem.Size := umlRandomRange(64, 512 * 1024);
  ZDB.PostP(Mem, True, nil, procedure(Sender: TZDB2; UserData: Pointer; ID: Integer; Successed: Boolean)
    begin
      if Successed then
        begin
          DoStatus('写入成功 ID:%d size:%d', [ID, Sender.Space.GetDataSize(Sender.Space.BlockBuffer[ID].ID)]);
          EditButton2Click(nil);
        end;
    end);
end;

procedure TZDB2CoreTestForm.EditButton3Click(Sender: TObject);
begin
  ZDB.RemoveP(EStrToInt(Edit2.Text, -1), True, nil, procedure(Sender: TZDB2; UserData: Pointer; ID: Integer; Successed: Boolean)
    begin
      if Successed then
          DoStatus('删除成功 ID:%d', [ID])
      else
          DoStatus('删除错误 ID:%d', [ID]);
    end);
end;

procedure TZDB2CoreTestForm.pbMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
begin
  mouse_pt := vec2(X, Y);
end;

procedure TZDB2CoreTestForm.pbPaint(Sender: TObject; Canvas: TCanvas);
const
  c_Metric = 20; // 呈现器度量单位
  c_Edge = 1;    // 呈现器边缘尺度
var
  d: TDrawEngine;
  f, i, j, num: Integer;
  X, Y: TGeoFloat;
  box, r: TRectV2;
  p: PZDB2_Block;
  hndID: Integer;
  State: PZDB2_Core_SpaceState;
  n: U_String;
begin
  dIntf.SetSurface(Canvas, Sender);
  d := DrawPool(Sender, dIntf);

  d.FillBox(d.ScreenRect, DEColor(0, 0, 0, 1));

  // 将并行处理数据画出来
  f := round(sqrt(ZDB.Space.BlockCount)); // 以平方根方式切割预览数据
  num := 0;
  X := 0;
  Y := 0;
  box := RectV2(X, Y, X, Y);
  p := nil;
  hndID := -1;
  for j := 0 to f do
    begin
      for i := 0 to f do
        begin
          r := RectV2(X, Y, X + c_Metric, Y + c_Metric);
          if num < ZDB.Space.BlockCount then
            begin
              if Vec2InRect(mouse_pt, d.SceneToScreen(r)) then
                begin
                  p := @ZDB.Space.BlockBuffer[num];
                  hndID := ZDB.Space.GetSpaceHndID(p^.ID);
                end;
            end;

          X := X + c_Metric + c_Edge;
          inc(num);
          box := BoundRect(box, r);
        end;
      Y := Y + c_Metric + c_Edge;
      X := 0;
    end;

  num := 0;
  X := 0;
  Y := 0;
  box := RectV2(X, Y, X, Y);
  for j := 0 to f do
    begin
      for i := 0 to f do
        begin
          r := RectV2(X, Y, X + c_Metric, Y + c_Metric);
          if num < ZDB.Space.BlockCount then
            with ZDB.Space.BlockBuffer[num] do
              begin
                if UsedSpace = Size then
                    d.FillBoxInScene(r, DEColor(1, 0, 0, 1))
                else if UsedSpace > 0 then
                    d.FillBoxInScene(r, DEColor(1, 0.5, 0.5, 1))
                else
                    d.FillBoxInScene(r, DEColor(0.5, 0.5, 0.5, 1));
              end;

          X := X + c_Metric + c_Edge;
          inc(num);
          box := BoundRect(box, r);
        end;
      Y := Y + c_Metric + c_Edge;
      X := 0;
    end;

  if hndID >= 0 then
    begin
      num := 0;
      X := 0;
      Y := 0;
      box := RectV2(X, Y, X, Y);
      for j := 0 to f do
        begin
          for i := 0 to f do
            begin
              r := RectV2(X, Y, X + c_Metric, Y + c_Metric);
              if num < ZDB.Space.BlockCount then
                with ZDB.Space.BlockBuffer[num] do
                  begin
                    if (UsedSpace > 0) and (ZDB.Space.GetSpaceHndID(ID) = hndID) then
                        d.DrawBox(d.SceneToScreen(r), DEColor(1, 1, 1), 2);
                  end;

              X := X + c_Metric + c_Edge;
              inc(num);
              box := BoundRect(box, r);
            end;
          Y := Y + c_Metric + c_Edge;
          X := 0;
        end;
    end;

  d.CameraR := rectEdge(box, 50);

  if (p <> nil) and (hndID >= 0) then
    begin
      n := Format('数据尺寸:%d 物理尺寸:%d ID:%d',
        [ZDB.Space.GetDataSize(hndID), ZDB.Space.GetDataPhysics(hndID), hndID]);

      n := TDrawEngine.RebuildNumAndWordColor(n, '|color(0.8,1,0.8)|', '||', [], []);
      d.BeginCaptureShadow(vec2(1, 1), 0.9);
      d.DrawText(n, 14, DEColor(1, 1, 1), Vec2Add(mouse_pt, vec2(15, 0)));
      d.EndCaptureShadow;
    end;

  with ZDB.Space.State^ do
    begin
      n := Format('数据条目:%d 数据库尺寸:%s 自由空间:%s 缓存:%s 读取统计:%d 读取流量:%s 写入次数统计:%d 写入流量:%s',
        [ZDB.Count,
        umlSizeToStr(Physics).Text,
        umlSizeToStr(FreeSpace).Text,
        umlSizeToStr(Cache).Text,
        ReadNum, umlSizeToStr(ReadSize).Text,
        WriteNum, umlSizeToStr(WriteSize).Text]) + #13#10 + TCompute.State;

      n := TDrawEngine.RebuildNumAndWordColor(n, '|color(1,0.5,0.5)|', '||', [], []);
      d.DrawText(n, 12, d.ScreenRect, DEColor(1, 1, 1, 1), False);
    end;
  d.Flush;
end;

procedure TZDB2CoreTestForm.Timer1Timer(Sender: TObject);
begin
  DrawPool.Progress();
  CoreClasses.CheckThreadSynchronize;
  Invalidate;
end;

end.
