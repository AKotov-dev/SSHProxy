program sshproxy;

{$mode objfpc}{$H+}

uses
 {$IFDEF UNIX}
  cthreads,
   {$ENDIF} {$IFDEF HASAMIGA}
  athreads,
   {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  Process,
  Classes,
  Dialogs,
  Unit1,
  portscan_trd { you can add units after this };

{$R *.res}

//--- Определяем, запущена ли копия программы
var
  PID: TStringList;
  ExProcess: TProcess;

begin
  ExProcess := TProcess.Create(nil);
  PID := TStringList.Create;
  try
    ExProcess.Executable := 'bash';
    ExProcess.Parameters.Add('-c');
    ExProcess.Parameters.Add('pidof sshproxy'); //Имя приложения
    ExProcess.Options := ExProcess.Options + [poUsePipes];

    ExProcess.Execute;
    PID.LoadFromStream(ExProcess.Output);

  finally
    ExProcess.Free;
  end;

  //Количество запущенных копий > 1 = не запускать новый экземпляр
  if Pos(' ', PID.Text) <> 0 then //пробел = более одного pid
  begin
    MessageDlg(SAppRunning, mtWarning, [mbOK], 0);
    PID.Free;
    Application.Free;
    Halt(1);
  end;
  PID.Free;

  //---

  RequireDerivedFormResource := True;
  Application.Title := 'SSHProxy-v0.1 (localhost:8080)';
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
