program ZDB2FileEncoder;

uses
  Vcl.Forms,
  ZDB2FileEncoderFrm in 'ZDB2FileEncoderFrm.pas' {ZDB2FileEncoderForm},
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Windows10 Dark');
  Application.CreateForm(TZDB2FileEncoderForm, ZDB2FileEncoderForm);
  Application.Run;
end.
