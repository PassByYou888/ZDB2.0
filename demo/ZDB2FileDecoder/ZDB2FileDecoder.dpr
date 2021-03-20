program ZDB2FileDecoder;

uses
  Vcl.Forms,
  ZDB2FileDecoderFrm in 'ZDB2FileDecoderFrm.pas' {ZDB2FileDecoderForm},
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Windows10 Dark');
  Application.CreateForm(TZDB2FileDecoderForm, ZDB2FileDecoderForm);
  Application.Run;
end.
