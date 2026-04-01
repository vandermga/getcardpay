program GetCardPayApi;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Horse,
  ScopeApi in 'ScopeApi.pas';

var
  ScopeInitialized: Boolean = False;
  ScopeSessionOpened: Boolean = False;

function SafeInitializeScope: Boolean;
begin
  Result := False;
  try
    WriteLn('=== Scope API - Versão Funcional ===');

    if not LoadScopeDLL then
    begin
      Writeln('Erro: Não foi possível carregar a DLL do Scope');
      Exit;
    end;

    WriteLn('Testando funções:');
    WriteLn('  Status: ', GetScopeRealStatus);
    WriteLn('  Versão: ', GetScopeVersion);

    // Carrega configurações do scope.ini
    if LoadScopeConfig then
      WriteLn('  Configurações carregadas do scope.ini')
    else
      WriteLn('  AVISO: Não foi possível carregar scope.ini');

    WriteLn('Inicialização concluída!');

    ScopeInitialized := True;
    Result := True;

  except
    on E: Exception do
    begin
      Writeln('Exceção: ' + E.Message);
      UnloadScopeDLL;
    end;
  end;
end;

procedure SafeFinalizeScope;
begin
  try
    if ScopeInitialized then
    begin
      WriteLn('Finalizando Scope...');
      ScopeInitialized := False;
    end;
    UnloadScopeDLL;
  except
    on E: Exception do
      WriteLn('Erro na finalização: ', E.Message);
  end;
end;

begin
  if not FileExists('scopeapi.dll') then
  begin
    Writeln('Erro: scopeapi.dll não encontrada');
    Readln;
    Exit;
  end;

  if not SafeInitializeScope then
  begin
    Writeln('Falha na inicialização');
    Readln;
    Exit;
  end;

  try
    // Configuração do Horse para aceitar CORS e logs
    THorse.Use(procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    begin
      Res.RawWebResponse.SetCustomHeader('Access-Control-Allow-Origin', '*');
      Res.RawWebResponse.SetCustomHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      Res.RawWebResponse.SetCustomHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

      WriteLn('[HTTP] ', Req.RawWebRequest.Method, ' ', Req.RawWebRequest.PathInfo);
      Next();
    end);

    // GET /scope/status - Status real
    THorse.Get('/scope/status',
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
        StatusCode: Integer;
        StatusMsg: string;
      begin
        try
          StatusCode := GetScopeRealStatus;

          case StatusCode of
            0: StatusMsg := 'OK - Funcionando';
            65025: StatusMsg := 'Status Scope específico';
            -999: StatusMsg := 'Função não disponível';
            -998: StatusMsg := 'Erro na execução';
            else StatusMsg := 'Status: ' + StatusCode.ToString;
          end;

          Res.Send('{"status_code": ' + StatusCode.ToString +
                   ', "status_message": "' + StatusMsg + '"}').Status(200);
        except
          on E: Exception do
            Res.Send('{"error": "' + E.Message + '"}').Status(500);
        end;
      end);

    // GET /scope/version - Versão real funcional
    THorse.Get('/scope/version',
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
        Version: string;
      begin
        try
          Version := GetScopeVersion;
          Res.Send('{"version": "' + Version + '", "working": true}').Status(200);
        except
          on E: Exception do
            Res.Send('{"error": "' + E.Message + '"}').Status(500);
        end;
      end);

    // GET /scope/info - Informações completas
    THorse.Get('/scope/info',
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
        StatusCode: Integer;
        Version: string;
      begin
        try
          StatusCode := GetScopeRealStatus;
          Version := GetScopeVersion;

          Res.Send('{"scope": {"status_code": ' + StatusCode.ToString +
                   ', "version": "' + Version +
                   '", "dll_loaded": ' + BoolToStr(IsScopeLoaded, True) +
                   ', "timestamp": "' + DateTimeToStr(Now) + '"}}').Status(200);
        except
          on E: Exception do
            Res.Send('{"error": "' + E.Message + '"}').Status(500);
        end;
      end);

    // GET /test - Teste básico
    THorse.Get('/test',
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      begin
        Res.Send('{"message": "API funcionando", "scope_loaded": ' +
                 BoolToStr(IsScopeLoaded, True) + '}').Status(200);
      end);

    // GET /test/all - Executa todos os testes automaticamente
    THorse.Get('/test/all',
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
        TestResults: string;
        StatusCode, OpenResult, CreditoResult, DebitoResult: Integer;
        Version: string;
      begin
        try
          TestResults := '{"tests": {';

          // Teste 1: Status
          StatusCode := GetScopeRealStatus;
          TestResults := TestResults + '"status": {"code": ' + StatusCode.ToString + ', "success": ' + BoolToStr(StatusCode >= 0, True) + '}';

          // Teste 2: Versão
          Version := GetScopeVersion;
          TestResults := TestResults + ', "version": {"value": "' + Version + '", "success": ' + BoolToStr(Version <> 'VERSAO_NAO_DISPONIVEL', True) + '}';

          // Teste 3: Carregamento de configuração
          TestResults := TestResults + ', "config": {"success": ' + BoolToStr(LoadScopeConfig, True) + '}';

          // Teste 4: Abertura de sessão
          OpenResult := OpenScopeFromConfig;
          if OpenResult = 0 then
            ScopeSessionOpened := True;
          TestResults := TestResults + ', "open_session": {"code": ' + OpenResult.ToString + ', "success": ' + BoolToStr(OpenResult = 0, True) + '}';

          if OpenResult = 0 then
          begin
            // Teste 5: Transação de crédito (R$ 1,00)
            CreditoResult := CompraCartaoCredito('100', '0');
            TestResults := TestResults + ', "credito": {"code": ' + CreditoResult.ToString + ', "valor": "100", "success": ' + BoolToStr(CreditoResult = 0, True) + '}';

            // Teste 6: Transação de débito (R$ 1,00)
            DebitoResult := CompraCartaoDebito('100');
            TestResults := TestResults + ', "debito": {"code": ' + DebitoResult.ToString + ', "valor": "100", "success": ' + BoolToStr(DebitoResult = 0, True) + '}';
          end
          else
          begin
            TestResults := TestResults + ', "credito": {"skipped": "session_not_opened"}';
            TestResults := TestResults + ', "debito": {"skipped": "session_not_opened"}';
          end;

          TestResults := TestResults + '}, "timestamp": "' + DateTimeToStr(Now) + '"}';

          Res.Send(TestResults).Status(200);
        except
          on E: Exception do
            Res.Send('{"error": "' + E.Message + '"}').Status(500);
        end;
      end);

    // GET /debug/full - Diagnóstico completo
    THorse.Get('/debug/full',
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
        DebugInfo: string;
        StatusCode, OpenResult: Integer;
        Version: string;
        ConfigLoaded, ConnTest: Boolean;
      begin
        try
          DebugInfo := '{"full_debug": {';

          // 1. Status DLL
          DebugInfo := DebugInfo + '"dll": {"loaded": ' + BoolToStr(IsScopeLoaded, True);
          DebugInfo := DebugInfo + ', "functions": {"ScopeStatus": ' + BoolToStr(Assigned(ScopeStatus), True);
          DebugInfo := DebugInfo + ', "ScopeVersao": ' + BoolToStr(Assigned(ScopeVersao), True);
          DebugInfo := DebugInfo + ', "ScopeOpen": ' + BoolToStr(Assigned(ScopeOpen), True) + '}}';

          // 2. Versão e Status
          StatusCode := GetScopeRealStatus;
          Version := GetScopeVersion;
          DebugInfo := DebugInfo + ', "scope": {"status": ' + StatusCode.ToString;
          DebugInfo := DebugInfo + ', "version": "' + Version + '"}';

          // 3. Configuração
          ConfigLoaded := LoadScopeConfig;
          DebugInfo := DebugInfo + ', "config": {"loaded": ' + BoolToStr(ConfigLoaded, True);
          if ConfigLoaded then
          begin
            DebugInfo := DebugInfo + ', "empresa": "' + ScopeConfiguration.Empresa;
            DebugInfo := DebugInfo + '", "filial": "' + ScopeConfiguration.Filial;
            DebugInfo := DebugInfo + '", "pdv": "' + ScopeConfiguration.PDV;
            DebugInfo := DebugInfo + '", "server": "' + ScopeConfiguration.Name;
            DebugInfo := DebugInfo + '", "port": "' + ScopeConfiguration.Port + '"';
          end;
          DebugInfo := DebugInfo + '}';

          // 4. Teste de conectividade
          //ConnTest := TestScopeConnection;
          //DebugInfo := DebugInfo + ', "connectivity": ' + BoolToStr(ConnTest, True);

          // 5. Tentativa de abertura
          if ConfigLoaded then
          begin
            WriteLn('[FULL_DEBUG] Tentando abrir sessão...');
            OpenResult := OpenScope(ScopeConfiguration.Empresa, ScopeConfiguration.Filial, ScopeConfiguration.PDV);
            DebugInfo := DebugInfo + ', "open_attempt": {"result": ' + OpenResult.ToString;
            DebugInfo := DebugInfo + ', "success": ' + BoolToStr(OpenResult = 0, True);

            if OpenResult = 0 then
            begin
              ScopeSessionOpened := True;
              DebugInfo := DebugInfo + ', "message": "Sessão aberta com sucesso"';
            end
            else
            begin
              case OpenResult of
                -1: DebugInfo := DebugInfo + ', "message": "Parâmetros inválidos"';
                -2: DebugInfo := DebugInfo + ', "message": "Não foi possível conectar ao servidor"';
                -3: DebugInfo := DebugInfo + ', "message": "Empresa/Filial não cadastrada"';
                -4: DebugInfo := DebugInfo + ', "message": "PDV não cadastrado"';
                else DebugInfo := DebugInfo + ', "message": "Erro desconhecido"';
              end;
            end;
            DebugInfo := DebugInfo + '}';
          end
          else
          begin
            DebugInfo := DebugInfo + ', "open_attempt": {"skipped": "config_not_loaded"}';
          end;

          DebugInfo := DebugInfo + ', "session_status": ' + BoolToStr(ScopeSessionOpened, True);
          DebugInfo := DebugInfo + '}}';

          Res.Send(DebugInfo).Status(200);
        except
          on E: Exception do
            Res.Send('{"error": "' + E.Message + '"}').Status(500);
        end;
      end);

    // GET /debug/open - Debug específico do ScopeOpen
    THorse.Get('/debug/open',
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
        OpenResult: Integer;
        DebugInfo: string;
      begin
        try
          DebugInfo := '{"debug_open": {';

          // Carrega config se necessário
          if ScopeConfiguration.Empresa = '' then
            LoadScopeConfig;

          DebugInfo := DebugInfo + '"config": {"empresa": "' + ScopeConfiguration.Empresa +
                       '", "filial": "' + ScopeConfiguration.Filial +
                       '", "pdv": "' + ScopeConfiguration.PDV + '"}';

          // Tenta abrir
          WriteLn('[DEBUG] Tentando abrir sessão...');
          OpenResult := OpenScope(ScopeConfiguration.Empresa, ScopeConfiguration.Filial, ScopeConfiguration.PDV);

          DebugInfo := DebugInfo + ', "open_result": ' + OpenResult.ToString;
          DebugInfo := DebugInfo + ', "functions_loaded": {"ScopeOpen": ' + BoolToStr(Assigned(ScopeOpen), True) + '}';
          DebugInfo := DebugInfo + ', "dll_loaded": ' + BoolToStr(IsScopeLoaded, True);

          if OpenResult = 0 then
            ScopeSessionOpened := True;

          DebugInfo := DebugInfo + ', "session_opened": ' + BoolToStr(ScopeSessionOpened, True);
          DebugInfo := DebugInfo + '}}';

          Res.Send(DebugInfo).Status(200);
        except
          on E: Exception do
            Res.Send('{"error": "' + E.Message + '"}').Status(500);
        end;
      end);

    // POST /scope/open - Abre sessão automaticamente do scope.ini
    THorse.Post('/scope/open',
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
        ResultCode: Integer;
      begin
        try
          ResultCode := OpenScopeFromConfig;

          if ResultCode = 0 then
          begin
            ScopeSessionOpened := True;
            Res.Send('{"success": true, "message": "Sessão aberta com sucesso", "code": ' +
                     ResultCode.ToString + '}').Status(200);
          end
          else
          begin
            Res.Send('{"success": false, "message": "Erro ao abrir sessão", "code": ' +
                     ResultCode.ToString + '}').Status(400);
          end;
        except
          on E: Exception do
            Res.Send('{"error": "' + E.Message + '"}').Status(500);
        end;
      end);

    // POST /scope/open/manual - Abre sessão com parâmetros manuais
    THorse.Post('/scope/open/manual',
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
        ResultCode: Integer;
        Empresa, Filial, PDV: string;
        Body: string;
        StartPos, EndPos: Integer;
      begin
        try
          Body := Req.Body;

          // Parse simples do JSON (empresa, filial, pdv)
          Empresa := '0001'; // valores padrão
          Filial := '0001';
          PDV := '004';

          // Extrai valores do JSON se fornecidos
          if Pos('"empresa":', Body) > 0 then
          begin
            StartPos := Pos('"empresa":', Body) + 10;
            EndPos := Pos('"', Body, StartPos + 1);
            if EndPos > StartPos then
              Empresa := Copy(Body, StartPos + 1, EndPos - StartPos - 1);
          end;

          if Pos('"filial":', Body) > 0 then
          begin
            StartPos := Pos('"filial":', Body) + 9;
            EndPos := Pos('"', Body, StartPos + 1);
            if EndPos > StartPos then
              Filial := Copy(Body, StartPos + 1, EndPos - StartPos - 1);
          end;

          if Pos('"pdv":', Body) > 0 then
          begin
            StartPos := Pos('"pdv":', Body) + 6;
            EndPos := Pos('"', Body, StartPos + 1);
            if EndPos > StartPos then
              PDV := Copy(Body, StartPos + 1, EndPos - StartPos - 1);
          end;

          ResultCode := OpenScope(Empresa, Filial, PDV);

          if ResultCode = 0 then
          begin
            ScopeSessionOpened := True;
            Res.Send('{"success": true, "message": "Sessão aberta com sucesso", "code": ' +
                     ResultCode.ToString + ', "empresa": "' + Empresa +
                     '", "filial": "' + Filial + '", "pdv": "' + PDV + '"}').Status(200);
          end
          else
          begin
            Res.Send('{"success": false, "message": "Erro ao abrir sessão", "code": ' +
                     ResultCode.ToString + '}').Status(400);
          end;
        except
          on E: Exception do
            Res.Send('{"error": "' + E.Message + '"}').Status(500);
        end;
      end);

    // POST /scope/credito - Compra com cartão de crédito
    THorse.Post('/scope/credito',
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
        ResultCode: Integer;
        Valor, TxServico: string;
        Body: string;
        StartPos, EndPos: Integer;
      begin
        try
          if not ScopeSessionOpened then
          begin
            Res.Send('{"error": "Sessão não aberta. Use POST /scope/open primeiro"}').Status(400);
            Exit;
          end;

          Body := Req.Body;
          Valor := '10000'; // R$ 100,00 padrão
          TxServico := '0';  // sem taxa padrão

          // Extrai valor do JSON
          if Pos('"valor":', Body) > 0 then
          begin
            StartPos := Pos('"valor":', Body) + 8;
            EndPos := Pos('"', Body, StartPos + 1);
            if EndPos > StartPos then
              Valor := Copy(Body, StartPos + 1, EndPos - StartPos - 1);
          end;

          // Extrai taxa de serviço do JSON
          if Pos('"taxa":', Body) > 0 then
          begin
            StartPos := Pos('"taxa":', Body) + 7;
            EndPos := Pos('"', Body, StartPos + 1);
            if EndPos > StartPos then
              TxServico := Copy(Body, StartPos + 1, EndPos - StartPos - 1);
          end;

          ResultCode := CompraCartaoCredito(Valor, TxServico);

          Res.Send('{"transaction_started": true, "type": "credito", "valor": "' + Valor +
                   '", "taxa": "' + TxServico + '", "code": ' + ResultCode.ToString +
                   ', "message": "Acompanhe via GET /scope/status"}').Status(200);
        except
          on E: Exception do
            Res.Send('{"error": "' + E.Message + '"}').Status(500);
        end;
      end);

    // POST /scope/debito - Compra com cartão de débito
    THorse.Post('/scope/debito',
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
        ResultCode: Integer;
        Valor: string;
        Body: string;
        StartPos, EndPos: Integer;
      begin
        try
          if not ScopeSessionOpened then
          begin
            Res.Send('{"error": "Sessão não aberta. Use POST /scope/open primeiro"}').Status(400);
            Exit;
          end;

          Body := Req.Body;
          Valor := '5000'; // R$ 50,00 padrão

          // Extrai valor do JSON
          if Pos('"valor":', Body) > 0 then
          begin
            StartPos := Pos('"valor":', Body) + 8;
            EndPos := Pos('"', Body, StartPos + 1);
            if EndPos > StartPos then
              Valor := Copy(Body, StartPos + 1, EndPos - StartPos - 1);
          end;

          ResultCode := CompraCartaoDebito(Valor);

          Res.Send('{"transaction_started": true, "type": "debito", "valor": "' + Valor +
                   '", "code": ' + ResultCode.ToString +
                   ', "message": "Acompanhe via GET /scope/status"}').Status(200);
        except
          on E: Exception do
            Res.Send('{"error": "' + E.Message + '"}').Status(500);
        end;
      end);

    // GET /test/config - Testa apenas carregamento da configuração
    THorse.Get('/test/config',
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
        ConfigLoaded: Boolean;
      begin
        try
          ConfigLoaded := LoadScopeConfig;

          if ConfigLoaded then
          begin
            Res.Send('{"config_loaded": true, "empresa": "' + ScopeConfiguration.Empresa +
                     '", "filial": "' + ScopeConfiguration.Filial +
                     '", "pdv": "' + ScopeConfiguration.PDV +
                     '", "name": "' + ScopeConfiguration.Name +
                     '", "port": "' + ScopeConfiguration.Port + '"}').Status(200);
          end
          else
          begin
            Res.Send('{"config_loaded": false, "error": "Não foi possível carregar scope.ini"}').Status(400);
          end;
        except
          on E: Exception do
            Res.Send('{"error": "' + E.Message + '"}').Status(500);
        end;
      end);

    // GET /test/session-status - Verifica status da sessão
    THorse.Get('/test/session-status',
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      begin
        try
          Res.Send('{"session_opened": ' + BoolToStr(ScopeSessionOpened, True) +
                   ', "dll_loaded": ' + BoolToStr(IsScopeLoaded, True) +
                   ', "config_empresa": "' + ScopeConfiguration.Empresa +
                   '", "config_filial": "' + ScopeConfiguration.Filial + '"}').Status(200);
        except
          on E: Exception do
            Res.Send('{"error": "' + E.Message + '"}').Status(500);
        end;
      end);

    // GET /scope/coleta/messages - Obtém mensagens da coleta atual (Interface Coleta)
    THorse.Get('/scope/coleta/messages',
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
        StatusCode: Integer;
        Messages: string;
      begin
        try
          // Obtém o status atual
          StatusCode := GetScopeRealStatus;

          // Verifica se é um código de coleta (64512 a 64767 = 0xFC00 a 0xFCFF)
          // OU se está em andamento (65024) - neste caso também tenta obter mensagens
          if ((StatusCode >= 64512) and (StatusCode <= 64767)) or (StatusCode = 65024) then
          begin
            // Tenta obter as mensagens de coleta
            // Para status 65024, usa TipoParam=0 (padrão)
            Messages := GetColetaMessages(StatusCode);

            // Verifica se conseguiu obter mensagens válidas
            if (Pos('"msgOp1":', Messages) > 0) or (Pos('"msgCl1":', Messages) > 0) then
            begin
              // Mensagens de coleta obtidas com sucesso
              Res.Send(Messages).Status(200);
            end
            else
            begin
              // Não conseguiu obter mensagens, retorna status em andamento
              Res.Send('{"status": "em_andamento", "code": ' + StatusCode.ToString +
                       ', "message": "Transação em andamento, sem coleta disponível", "tentou_coleta": true}').Status(200);
            end;
          end
          else if StatusCode = 0 then
          begin
            // Transação aprovada
            Res.Send('{"status": "aprovada", "code": 0, "message": "Transação aprovada"}').Status(200);
          end
          else
          begin
            // Outro status
            Res.Send('{"status": "outro", "code": ' + StatusCode.ToString +
                     ', "message": "Status não é de coleta"}').Status(200);
          end;
        except
          on E: Exception do
            Res.Send('{"error": "' + E.Message + '"}').Status(500);
        end;
      end);

    // POST /scope/coleta/resume - Envia dado coletado de volta ao Scope
    THorse.Post('/scope/coleta/resume',
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
        ResultCode: Integer;
        Dado: string;
        Acao: Integer;
        Body: string;
        StartPos, EndPos: Integer;
      begin
        try
          Body := Req.Body;
          Dado := '';
          Acao := 0; // Próximo por padrão

          // Extrai dado do JSON
          if Pos('"dado":', Body) > 0 then
          begin
            StartPos := Pos('"dado":', Body) + 7;
            EndPos := Pos('"', Body, StartPos + 1);
            if EndPos > StartPos then
              Dado := Copy(Body, StartPos + 1, EndPos - StartPos - 1);
          end;

          // Extrai ação do JSON (0=Próximo, 1=Anterior, 2=Cancelar)
          if Pos('"acao":', Body) > 0 then
          begin
            StartPos := Pos('"acao":', Body) + 7;
            EndPos := StartPos;
            while (EndPos <= Length(Body)) and (Body[EndPos] in ['0'..'9']) do
              Inc(EndPos);
            if EndPos > StartPos then
              Acao := StrToIntDef(Copy(Body, StartPos, EndPos - StartPos), 0);
          end;

          ResultCode := ResumeParamColeta(Dado, Acao);

          if ResultCode = 0 then
          begin
            Res.Send('{"success": true, "message": "Dado enviado com sucesso", ' +
                     '"dado": "' + Dado + '", "acao": ' + Acao.ToString + '}').Status(200);
          end
          else
          begin
            Res.Send('{"success": false, "message": "Erro ao enviar dado", ' +
                     '"code": ' + ResultCode.ToString + '}').Status(400);
          end;
        except
          on E: Exception do
            Res.Send('{"error": "' + E.Message + '"}').Status(500);
        end;
      end);

    // GET /scope/coleta/status-detalhado - Status com informações de coleta se disponível
    THorse.Get('/scope/coleta/status-detalhado',
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
        StatusCode: Integer;
        Messages: string;
        Response: string;
      begin
        try
          StatusCode := GetScopeRealStatus;

          Response := '{"status_code": ' + StatusCode.ToString;

          // Verifica se é código de coleta
          if (StatusCode >= 64512) and (StatusCode <= 64767) then
          begin
            Messages := GetColetaMessages(StatusCode);
            Response := Response + ', "tipo": "coleta", "coleta": ' + Messages;
          end
          else if StatusCode = 65024 then
          begin
            Response := Response + ', "tipo": "em_andamento", "message": "Aguardando processamento"';
          end
          else if StatusCode = 0 then
          begin
            Response := Response + ', "tipo": "aprovada", "message": "Transação aprovada"';
          end
          else if StatusCode > 64512 then
          begin
            Response := Response + ', "tipo": "erro", "message": "Erro na transação"';
          end
          else
          begin
            Response := Response + ', "tipo": "outro"';
          end;

          Response := Response + '}';
          Res.Send(Response).Status(200);
        except
          on E: Exception do
            Res.Send('{"error": "' + E.Message + '"}').Status(500);
        end;
      end);

    Writeln('🎉 SERVIDOR SCOPE API FUNCIONANDO! 🎉');
    Writeln('Porta: 4040');
    Writeln('Endpoints de Informação:');
    Writeln('  GET   /test              - Teste básico da API');
    Writeln('  GET   /test/all          - Executa todos os testes');
    Writeln('  GET   /test/config       - Testa carregamento scope.ini');
    Writeln('  GET   /test/session-status - Status da sessão');
    Writeln('  GET   /debug/full        - Diagnóstico COMPLETO');
    Writeln('  GET   /debug/open        - Debug do ScopeOpen');
    Writeln('  GET   /scope/status      - Status Scope: ', GetScopeRealStatus);
    Writeln('  GET   /scope/version     - Versão: ', GetScopeVersion);
    Writeln('  GET   /scope/info        - Info completa');
    Writeln('');
    Writeln('Endpoints de Operação:');
    Writeln('  POST  /scope/open        - Abrir sessão (scope.ini)');
    Writeln('  POST  /scope/open/manual - Abrir sessão (manual)');
    Writeln('  POST  /scope/credito     - Compra crédito');
    Writeln('  POST  /scope/debito      - Compra débito');
    Writeln('');
    Writeln('Endpoints de Interface Coleta:');
    Writeln('  GET   /scope/coleta/messages        - Obtém mensagens da coleta atual');
    Writeln('  POST  /scope/coleta/resume          - Envia dado coletado');
    Writeln('  GET   /scope/coleta/status-detalhado - Status com detalhes de coleta');
    Writeln('');
    Writeln('Status atual:');
    Writeln('  DLL carregada:', BoolToStr(IsScopeLoaded, True));
    Writeln('  Sessão aberta:', BoolToStr(ScopeSessionOpened, True));
    if ScopeConfiguration.Empresa <> '' then
    begin
      Writeln('  Empresa/Filial:', ScopeConfiguration.Empresa, '/', ScopeConfiguration.Filial);
    end;
    Writeln('');
    Writeln('🔍 DIAGNÓSTICO: GET /debug/full');
    Writeln('📝 TESTE TUDO: GET /test/all');
    Writeln('Pressione Enter para parar...');

    THorse.Listen(4040);
    Readln;

  finally
    SafeFinalizeScope;
  end;
end.


