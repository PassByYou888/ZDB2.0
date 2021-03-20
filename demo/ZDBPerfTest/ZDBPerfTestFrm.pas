unit ZDBPerfTestFrm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,

  System.IOUtils,

  CoreClasses, PascalStrings, DoStatusIO, UnicodeMixedLib, MemoryStream64, CoreCipher,
  zExpression, ZDB2_Core, ZDB2, ZIOThread, Vcl.ComCtrls;

type
  TZDBPerfTestForm = class(TForm)
    FileEdit: TLabeledEdit;
    PhySpaceEdit: TLabeledEdit;
    BlockSizeEdit: TLabeledEdit;
    NewFileButton: TButton;
    Memo: TMemo;
    checkTimer: TTimer;
    CloseDBButton: TButton;
    ProgressBar: TProgressBar;
    FillDBButton: TButton;
    StateLabel: TLabel;
    stateTimer: TTimer;
    TraversalButton: TButton;
    AppendSpaceButton: TButton;
    procedure AppendSpaceButtonClick(Sender: TObject);
    procedure CloseDBButtonClick(Sender: TObject);
    procedure NewFileButtonClick(Sender: TObject);
    procedure checkTimerTimer(Sender: TObject);
    procedure FillDBButtonClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure stateTimerTimer(Sender: TObject);
    procedure TraversalButtonClick(Sender: TObject);
  private
    procedure DoStatus_Bcakcall(Text_: SystemString; const ID: Integer);
    procedure ZDBCoreProgress(Total_, current_: Integer);
  public
    ZDB: TZDB2;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  ZDBPerfTestForm: TZDBPerfTestForm;

implementation

{$R *.dfm}


procedure TZDBPerfTestForm.checkTimerTimer(Sender: TObject);
begin
  CheckThreadSynchronize;
end;

procedure TZDBPerfTestForm.ZDBCoreProgress(Total_, current_: Integer);
begin
  if current_ mod 1000 = 0 then
    begin
      ProgressBar.Max := Total_;
      ProgressBar.Position := current_;
    end;
end;

procedure TZDBPerfTestForm.DoStatus_Bcakcall(Text_: SystemString; const ID: Integer);
begin
  Memo.Lines.Add(Text_);
end;

constructor TZDBPerfTestForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  WorkInParallelCore.V := True;
  AddDoStatusHook(Self, DoStatus_Bcakcall);
  ZDB := TZDB2.Create;
  FileEdit.Text := umlCombineFileName(TPath.GetLibraryPath, 'ZDB2Test.dat');
  PhySpaceEdit.Text := '1024*1024*1024*20';
  BlockSizeEdit.Text := '$FFFF';
end;

destructor TZDBPerfTestForm.Destroy;
begin
  DeleteDoStatusHook(Self);
  inherited Destroy;
end;

procedure TZDBPerfTestForm.AppendSpaceButtonClick(Sender: TObject);
begin
  if ZDB = nil then
      exit;
  if ZDB.Space = nil then
      exit;

  ZDB.AppendSpace(
    EStrToInt64(PhySpaceEdit.Text, 1024 * 1024 * 512),
    EStrToInt64(BlockSizeEdit.Text, $FFFF)
    );
end;

procedure TZDBPerfTestForm.CloseDBButtonClick(Sender: TObject);
begin
  DisposeObjectAndNIl(ZDB);
end;

procedure TZDBPerfTestForm.FillDBButtonClick(Sender: TObject);
var
  mem: TZDB2_Mem;
  i: Integer;
begin
  if ZDB = nil then
      exit;
  if ZDB.Space = nil then
      exit;

  mem := TZDB2_Mem.Create;
  mem.Size := EStrToInt64(BlockSizeEdit.Text, $FFFF);

  for i := 0 to ZDB.Space.State^.FreeSpace div mem.Size - 2 do
      ZDB.Post(mem, false);
  ZDB.Post(mem, True);
  ZDB.Save(false);
end;

procedure TZDBPerfTestForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  DisposeObjectAndNIl(ZDB);
end;

procedure TZDBPerfTestForm.NewFileButtonClick(Sender: TObject);
begin
  DisposeObjectAndNIl(ZDB);
  Enabled := false;
  TCompute.RunP_NP(procedure
    begin
      ZDB := TZDB2.Create;
      ZDB.NoSpace := TZDB2_NoSpace.nsError;
      ZDB.OnCoreProgress := ZDBCoreProgress;
      ZDB.NewFile(FileEdit.Text,
        EStrToInt64(PhySpaceEdit.Text, 1024 * 1024 * 512),
        EStrToInt64(BlockSizeEdit.Text, $FFFF),
        TZDB2_SpaceMode.smBigData
        );
      TCompute.Sync(procedure
        begin
          Enabled := True;
        end);
      DoStatus('创建数据库完成: 文件默认IO以数据0填充');
      DoStatus('单元数量:%d', [ZDB.Space.BlockCount]);
    end);
end;

procedure TZDBPerfTestForm.stateTimerTimer(Sender: TObject);
begin
  if Enabled then
    if ZDB <> nil then
      if ZDB.Space <> nil then
        with ZDB.Space.State^ do
            StateLabel.Caption := Format('物理空间:%s 自由空间:%s IO读:%s IO写:%s 数据条目:%d',
            [umlSizeToStr(Physics).Text,
            umlSizeToStr(FreeSpace).Text,
            umlSizeToStr(ReadSize).Text,
            umlSizeToStr(WriteSize).Text,
            ZDB.Count]);
end;

procedure TZDBPerfTestForm.TraversalButtonClick(Sender: TObject);
begin
  if ZDB = nil then
      exit;
  if ZDB.Space = nil then
      exit;

  ZDB.TraversalP(false, false, nil,
    procedure(ZSender: TZDB2; Traversal: TZDB2_Traversal; mem: TZDB2_Mem; var Running: Boolean)
    begin
      ZDBCoreProgress(Traversal.Total, Traversal.Current);
    end,
    procedure(ZSender: TZDB2; Traversal: TZDB2_Traversal)
    var
      i: Integer;
    begin
      DoStatus('全数据遍历耗时 %s', [umlTimeTickToStr(Traversal.Timer).Text]);
    end);
end;

end.
