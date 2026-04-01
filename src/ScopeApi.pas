unit ScopeAPI;

interface

uses
  Windows, SysUtils, IniFiles, Classes;

const
  SCOPE_DLL = 'scopeapi.dll';
  SCOPE_INI = 'scope.ini';

type
  TScopeConfig = record
    Empresa: string;
    Filial: string;
    PDV: string;
    Name: string;
    Port: string;
  end;

var
  ScopeHandle: HMODULE = 0;
  ScopeConfiguration: TScopeConfig;

type
  // Estrutura para capturar parâmetros de coleta (Interface Coleta)
  TParamColeta = packed record
    Bandeira: Word;              // Código da bandeira
    FormatoDado: Word;           // Formato do dado a coletar
    HabTeclas: Word;             // Teclas habilitadas (bitwise)
    MsgOp1: array[0..63] of AnsiChar;  // Mensagem operador linha 1
    MsgOp2: array[0..63] of AnsiChar;  // Mensagem operador linha 2
    MsgCl1: array[0..63] of AnsiChar;  // Mensagem cliente linha 1
    MsgCl2: array[0..63] of AnsiChar;  // Mensagem cliente linha 2
    WrkKey: array[0..16] of AnsiChar;  // Working Key para PIN-Pad
    PosMasterKey: Word;          // Posição da Master Key
    PAN: array[0..19] of AnsiChar;     // Número do cartão
    UsaCriptoPinpad: Byte;       // Usa criptografia no PIN-Pad
    IdModoPagto: Byte;           // ID modo de pagamento
    AceitaCartaoDigitado: Byte;  // Aceita cartão digitado
    Reservado: array[0..104] of Byte;  // Reservado para uso futuro
  end;
  PParamColeta = ^TParamColeta;

  TScopeStatus = function: Integer; cdecl;
  TScopeVersao = function(Buffer: PAnsiChar; Size: Integer): Integer; cdecl;
  TScopeOpen = function(Modo: PAnsiChar; Empresa: PAnsiChar; Filial: PAnsiChar; PDV: PAnsiChar): Integer; cdecl;
  TScopeCompraCartaoCredito = function(Valor: PAnsiChar; TxServico: PAnsiChar): Integer; cdecl;
  TScopeCompraCartaoDebito = function(Valor: PAnsiChar): Integer; cdecl;
  TScopeGetParam = function(TipoParam: Integer; lpParam: PParamColeta): Integer; cdecl;
  TScopeResumeParam = function(Dado: PAnsiChar; TamDado: Integer; Acao: Integer): Integer; cdecl;

var
  ScopeStatus: TScopeStatus = nil;
  ScopeVersao: TScopeVersao = nil;
  ScopeOpen: TScopeOpen = nil;
  ScopeCompraCartaoCredito: TScopeCompraCartaoCredito = nil;
  ScopeCompraCartaoDebito: TScopeCompraCartaoDebito = nil;
  ScopeGetParam: TScopeGetParam = nil;
  ScopeResumeParam: TScopeResumeParam = nil;

function LoadScopeDLL: Boolean;
procedure UnloadScopeDLL;
function IsScopeLoaded: Boolean;
function GetScopeRealStatus: Integer;
function GetScopeVersion: string;
function LoadScopeConfig: Boolean;
function OpenScopeFromConfig: Integer;
function OpenScope(Empresa, Filial, PDV: string): Integer;
function TestScopeConnection: Boolean;
function CompraCartaoCredito(Valor, TxServico: string): Integer;
function CompraCartaoDebito(Valor: string): Integer;
function GetParamColeta(TipoParam: Integer; var ParamColeta: TParamColeta): Integer;
function ResumeParamColeta(Dado: string; Acao: Integer): Integer;
function GetColetaMessages(TipoParam: Integer): string;

implementation

function LoadScopeDLL: Boolean;
begin
  Result := False;

  if ScopeHandle <> 0 then
  begin
    Result := True;
    Exit;
  end;

  try
    ScopeHandle := LoadLibrary(SCOPE_DLL);
    if ScopeHandle = 0 then
    begin
      WriteLn('Erro: Não foi possível carregar ', SCOPE_DLL);
      Exit;
    end;

    // Carrega as funções com assinaturas corretas
    @ScopeStatus := GetProcAddress(ScopeHandle, 'ScopeStatus');
    @ScopeVersao := GetProcAddress(ScopeHandle, 'ScopeVersao');
    @ScopeOpen := GetProcAddress(ScopeHandle, 'ScopeOpen');
    @ScopeCompraCartaoCredito := GetProcAddress(ScopeHandle, 'ScopeCompraCartaoCredito');
    @ScopeCompraCartaoDebito := GetProcAddress(ScopeHandle, 'ScopeCompraCartaoDebito');
    @ScopeGetParam := GetProcAddress(ScopeHandle, 'ScopeGetParam');
    @ScopeResumeParam := GetProcAddress(ScopeHandle, 'ScopeResumeParam');

    WriteLn('Funções carregadas:');
    WriteLn('  ScopeStatus: ', Assigned(ScopeStatus));
    WriteLn('  ScopeVersao: ', Assigned(ScopeVersao));
    WriteLn('  ScopeOpen: ', Assigned(ScopeOpen));
    WriteLn('  ScopeCompraCartaoCredito: ', Assigned(ScopeCompraCartaoCredito));
    WriteLn('  ScopeCompraCartaoDebito: ', Assigned(ScopeCompraCartaoDebito));
    WriteLn('  ScopeGetParam: ', Assigned(ScopeGetParam));
    WriteLn('  ScopeResumeParam: ', Assigned(ScopeResumeParam));

    Result := True;

  except
    on E: Exception do
    begin
      WriteLn('Exceção ao carregar DLL: ', E.Message);
      if ScopeHandle <> 0 then
      begin
        FreeLibrary(ScopeHandle);
        ScopeHandle := 0;
      end;
    end;
  end;
end;

procedure UnloadScopeDLL;
begin
  try
    if ScopeHandle <> 0 then
    begin
      FreeLibrary(ScopeHandle);
      ScopeHandle := 0;
      ScopeStatus := nil;
      ScopeVersao := nil;
      ScopeOpen := nil;
      ScopeCompraCartaoCredito := nil;
      ScopeCompraCartaoDebito := nil;
    end;
  except
    on E: Exception do
      WriteLn('Erro ao descarregar DLL: ', E.Message);
  end;
end;

function IsScopeLoaded: Boolean;
begin
  Result := ScopeHandle <> 0;
end;

function GetScopeRealStatus: Integer;
begin
  Result := -999;

  try
    if not Assigned(ScopeStatus) then
    begin
      WriteLn('[STATUS] Função ScopeStatus não carregada');
      Exit;
    end;

    WriteLn('[STATUS] Chamando ScopeStatus...');
    Result := ScopeStatus();
    WriteLn('[STATUS] ScopeStatus retornou: ', Result);

  except
    on E: Exception do
    begin
      WriteLn('[STATUS] Erro: ', E.Message);
      Result := -998;
    end;
  end;
end;

function GetScopeVersion: string;
var
  Buffer: array[0..255] of AnsiChar;
  ResultCode: Integer;
begin
  Result := 'VERSAO_NAO_DISPONIVEL';

  try
    if not Assigned(ScopeVersao) then
    begin
      WriteLn('[VERSAO] Função ScopeVersao não carregada');
      Exit;
    end;

    WriteLn('[VERSAO] Chamando ScopeVersao com buffer...');
    FillChar(Buffer, SizeOf(Buffer), 0);

    ResultCode := ScopeVersao(@Buffer[0], SizeOf(Buffer));

    if ResultCode = 0 then
    begin
      Result := string(Buffer);
      WriteLn('[VERSAO] Versão obtida: ', Result);
    end
    else
    begin
      WriteLn('[VERSAO] Erro. Código: ', ResultCode);
      Result := 'ERRO_CODIGO_' + ResultCode.ToString;
    end;

  except
    on E: Exception do
    begin
      WriteLn('[VERSAO] Erro: ', E.Message);
      Result := 'ERRO_EXCEPTION';
    end;
  end;
end;

function OpenScope(Empresa, Filial, PDV: string): Integer;
var
  ModoStr: AnsiString;
  EmpresaStr: AnsiString;
  FilialStr: AnsiString;
  PDVStr: AnsiString;
begin
  Result := -999;

  try
    if not Assigned(ScopeOpen) then
    begin
      WriteLn('[OPEN] Função ScopeOpen não carregada');
      Exit;
    end;

    // Valida tamanhos dos parâmetros conforme documentação
    if Length(Empresa) <> 4 then
    begin
      WriteLn('[OPEN] ✗ Erro: Empresa deve ter exatamente 4 dígitos');
      Result := -1;
      Exit;
    end;

    if Length(Filial) <> 4 then
    begin
      WriteLn('[OPEN] ✗ Erro: Filial deve ter exatamente 4 dígitos');
      Result := -1;
      Exit;
    end;

    if Length(PDV) <> 3 then
    begin
      WriteLn('[OPEN] ✗ Erro: PDV deve ter exatamente 3 dígitos');
      Result := -1;
      Exit;
    end;

    // Prepara os parâmetros como AnsiString
    ModoStr := '0';  // Modo padrão conforme manual - STRING CONSTANTE "2"
    EmpresaStr := AnsiString(Empresa);
    FilialStr := AnsiString(Filial);
    PDVStr := AnsiString(PDV);
    //PDVStr := AnsiString('026');

    WriteLn('[OPEN] Abrindo sessão...');
    WriteLn('[OPEN] Empresa: "', Empresa, '" (Length: ', Length(Empresa), ')');
    WriteLn('[OPEN] Filial: "', Filial, '" (Length: ', Length(Filial), ')');
    WriteLn('[OPEN] PDV: "', PDV, '" (Length: ', Length(PDV), ')');
    WriteLn('[OPEN] Modo: "', ModoStr, '"');

    Result := ScopeOpen(PAnsiChar(ModoStr), PAnsiChar(EmpresaStr), PAnsiChar(FilialStr), PAnsiChar(PDVStr));

    WriteLn('[OPEN] ScopeOpen retornou: ', Result);

    case Result of
      0: WriteLn('[OPEN] ✓ Sessão aberta com sucesso');
      65025: WriteLn('[OPEN] ⚠ SCOPE API não foi inicializada corretamente');
      65024: WriteLn('[OPEN] ⚠ Transação em andamento - aguardar');
      65290: WriteLn('[OPEN] ✗ Parâmetro 1 inválido (Modo)');
      65291: WriteLn('[OPEN] ✗ Parâmetro 2 inválido (Empresa)');
      65292: WriteLn('[OPEN] ✗ Parâmetro 3 inválido (Filial)');
      65293: WriteLn('[OPEN] ✗ Parâmetro 4 inválido (PDV)');
      65298: WriteLn('[OPEN] ✗ Logon duplicado');
      65299: WriteLn('[OPEN] ✗ Protocolo não suportado');
      65300: WriteLn('[OPEN] ✗ POS não cadastrado');
      65301: WriteLn('[OPEN] ✗ Não há mais PDVs disponíveis');
      65302: WriteLn('[OPEN] ✗ Protocolo incompatível');
      65303: WriteLn('[OPEN] ✗ Erro ao verificar mensagem');
      65304: WriteLn('[OPEN] ✗ ScopeSrv off-line ou IP incorreto');
      65305: WriteLn('[OPEN] ✗ Banco de dados off-line');
      65309: WriteLn('[OPEN] ✗ Sessão em andamento');
      65535: WriteLn('[OPEN] ✗ Erro genérico (verificar configuração e conectividade)');
      else WriteLn('[OPEN] ✗ Erro desconhecido. Código: ', Result);
    end;

  except
    on E: Exception do
    begin
      WriteLn('[OPEN] Erro: ', E.Message);
      Result := -998;
    end;
  end;
end;

function CompraCartaoCredito(Valor, TxServico: string): Integer;
var
  ValorStr: AnsiString;
  TxServicoStr: AnsiString;
begin
  Result := -999;

  try
    if not Assigned(ScopeCompraCartaoCredito) then
    begin
      WriteLn('[CREDITO] Função ScopeCompraCartaoCredito não carregada');
      Exit;
    end;

    // Prepara os parâmetros como AnsiString
    ValorStr := AnsiString(Valor);
    TxServicoStr := AnsiString(TxServico);

    WriteLn('[CREDITO] Iniciando compra com cartão de crédito...');
    WriteLn('[CREDITO] Valor: ', Valor);
    WriteLn('[CREDITO] Taxa Serviço: ', TxServico);

    Result := ScopeCompraCartaoCredito(PAnsiChar(ValorStr), PAnsiChar(TxServicoStr));

    WriteLn('[CREDITO] ScopeCompraCartaoCredito retornou: ', Result);

    if Result = 0 then
      WriteLn('[CREDITO] Transação de crédito iniciada com sucesso')
    else
      WriteLn('[CREDITO] Erro na transação de crédito. Código: ', Result);

  except
    on E: Exception do
    begin
      WriteLn('[CREDITO] Erro: ', E.Message);
      Result := -998;
    end;
  end;
end;

function CompraCartaoDebito(Valor: string): Integer;
var
  ValorStr: AnsiString;
begin
  Result := -999;

  try
    if not Assigned(ScopeCompraCartaoDebito) then
    begin
      WriteLn('[DEBITO] Função ScopeCompraCartaoDebito não carregada');
      Exit;
    end;

    // Prepara o parâmetro como AnsiString
    ValorStr := AnsiString(Valor);

    WriteLn('[DEBITO] Iniciando compra com cartão de débito...');
    WriteLn('[DEBITO] Valor: ', Valor);

    Result := ScopeCompraCartaoDebito(PAnsiChar(ValorStr));

    WriteLn('[DEBITO] ScopeCompraCartaoDebito retornou: ', Result);

    if Result = 0 then
      WriteLn('[DEBITO] Transação de débito iniciada com sucesso')
    else
      WriteLn('[DEBITO] Erro na transação de débito. Código: ', Result);

  except
    on E: Exception do
    begin
      WriteLn('[DEBITO] Erro: ', E.Message);
      Result := -998;
    end;
  end;
end;

function LoadScopeConfig: Boolean;
var
  IniFile: TIniFile;
  ScopeIniPath: string;
  SectionName: string;
  Sections: TStringList;
  i: Integer;
  TempInt: Integer;
begin
  Result := False;

  try
    // Busca o scope.ini no diretório do executável
    ScopeIniPath := ExtractFilePath(ParamStr(0)) + SCOPE_INI;

    if not FileExists(ScopeIniPath) then
    begin
      WriteLn('[CONFIG] Arquivo scope.ini não encontrado em: ', ScopeIniPath);
      Exit;
    end;

    WriteLn('[CONFIG] Carregando configurações de: ', ScopeIniPath);
    IniFile := TIniFile.Create(ScopeIniPath);

    try
      SectionName := '';

      // Vamos procurar pela primeira seção que tenha 8 dígitos (formato empresa+filial)
      Sections := TStringList.Create;
      try
        IniFile.ReadSections(Sections);
        for i := 0 to Sections.Count - 1 do
        begin
          if (Length(Sections[i]) = 8) and TryStrToInt(Sections[i], TempInt) then
          begin
            SectionName := Sections[i];
            Break;
          end;
        end;
      finally
        Sections.Free;
      end;

      if SectionName = '' then
      begin
        WriteLn('[CONFIG] Seção com código empresa/filial não encontrada no scope.ini');
        Exit;
      end;

      // Extrai empresa e filial do nome da seção
      ScopeConfiguration.Empresa := Copy(SectionName, 1, 4);
      ScopeConfiguration.Filial := Copy(SectionName, 5, 4);
      ScopeConfiguration.PDV := '001'; // PDV padrão

      // Lê configurações da seção
      ScopeConfiguration.Name := IniFile.ReadString(SectionName, 'Name', '');
      ScopeConfiguration.Port := IniFile.ReadString(SectionName, 'Port', '');

      WriteLn('[CONFIG] Configurações carregadas:');
      WriteLn('[CONFIG]   Empresa: ', ScopeConfiguration.Empresa);
      WriteLn('[CONFIG]   Filial: ', ScopeConfiguration.Filial);
      WriteLn('[CONFIG]   PDV: ', ScopeConfiguration.PDV);
      WriteLn('[CONFIG]   Name: ', ScopeConfiguration.Name);
      WriteLn('[CONFIG]   Port: ', ScopeConfiguration.Port);

      Result := True;

    finally
      IniFile.Free;
    end;

  except
    on E: Exception do
    begin
      WriteLn('[CONFIG] Erro ao carregar scope.ini: ', E.Message);
    end;
  end;
end;

function OpenScopeFromConfig: Integer;
begin
  Result := -999;

  try
    // Carrega configurações se ainda não foram carregadas
    if (ScopeConfiguration.Empresa = '') and not LoadScopeConfig then
    begin
      WriteLn('[OPEN_CONFIG] Falha ao carregar configurações do scope.ini');
      Exit;
    end;

    // Testa conectividade antes de tentar abrir
//    if not TestScopeConnection then
//    begin
//      WriteLn('[OPEN_CONFIG] Falha no teste de conectividade');
//      Result := -997;
//      Exit;
//    end;

    // Verifica se a DLL está carregada
    if not IsScopeLoaded then
    begin
      WriteLn('[OPEN_CONFIG] DLL não está carregada');
      Result := -996;
      Exit;
    end;

    // Verifica o status antes de tentar abrir
    WriteLn('[OPEN_CONFIG] Verificando status atual...');
    Result := GetScopeRealStatus;
    WriteLn('[OPEN_CONFIG] Status atual: ', Result);

    // Se já está conectado (status 0), não precisa abrir novamente
    if Result = 0 then
    begin
      WriteLn('[OPEN_CONFIG] ✓ Sessão já está aberta');
      Exit;
    end;

    WriteLn('[OPEN_CONFIG] Abrindo sessão com configurações do scope.ini...');
    Result := OpenScope(ScopeConfiguration.Empresa, ScopeConfiguration.Filial, ScopeConfiguration.PDV);

  except
    on E: Exception do
    begin
      WriteLn('[OPEN_CONFIG] Erro: ', E.Message);
      Result := -998;
    end;
  end;
end;

function TestScopeConnection: Boolean;
var
  IniFile: TIniFile;
  ScopeIniPath: string;
  SectionName: string;
  Sections: TStringList;
  i: Integer;
  TempInt: Integer;
begin
  Result := False;
  try
    // Verifica se as configurações estão carregadas
    if ScopeConfiguration.Empresa = '' then
      LoadScopeConfig;

    WriteLn('[TEST_CONN] Testando conectividade...');
    WriteLn('[TEST_CONN] Servidor: ', ScopeConfiguration.Name, ':', ScopeConfiguration.Port);

    // Verifica se temos configurações válidas
    if (ScopeConfiguration.Name = '') or (ScopeConfiguration.Port = '') then
    begin
      WriteLn('[TEST_CONN] ✗ Configurações de rede incompletas');
      Exit;
    end;

    // Verifica se o arquivo scope.ini existe e está acessível
    ScopeIniPath := ExtractFilePath(ParamStr(0)) + SCOPE_INI;
    if not FileExists(ScopeIniPath) then
    begin
      WriteLn('[TEST_CONN] ✗ Arquivo scope.ini não encontrado');
      Exit;
    end;

    try
      // Tenta ler o arquivo para verificar se está acessível
      IniFile := TIniFile.Create(ScopeIniPath);
      try
        Sections := TStringList.Create;
        try
          IniFile.ReadSections(Sections);

          // Procura seção empresa/filial
          SectionName := '';
          for i := 0 to Sections.Count - 1 do
          begin
            if (Length(Sections[i]) = 8) and TryStrToInt(Sections[i], TempInt) then
            begin
              SectionName := Sections[i];
              Break;
            end;
          end;

          if SectionName = '' then
          begin
            WriteLn('[TEST_CONN] ✗ Seção empresa/filial não encontrada no scope.ini');
            Exit;
          end;

        finally
          Sections.Free;
        end;
      finally
        IniFile.Free;
      end;
    except
      on E: Exception do
      begin
        WriteLn('[TEST_CONN] ✗ Erro ao acessar scope.ini: ', E.Message);
        Exit;
      end;
    end;

    WriteLn('[TEST_CONN] ✓ Configurações de rede OK');
    WriteLn('[TEST_CONN] ✓ Arquivo scope.ini acessível');
    WriteLn('[TEST_CONN] ✓ Seção empresa/filial encontrada: [', ScopeConfiguration.Empresa + ScopeConfiguration.Filial, ']');
    Result := True;

  except
    on E: Exception do
    begin
      WriteLn('[TEST_CONN] Erro: ', E.Message);
      Result := False;
    end;
  end;
end;

// ======================================================
// FUNÇÕES PARA INTERFACE COLETA
// ======================================================

function GetParamColeta(TipoParam: Integer; var ParamColeta: TParamColeta): Integer;
begin
  Result := -999;

  try
    if not Assigned(ScopeGetParam) then
    begin
      WriteLn('[GET_PARAM] Função ScopeGetParam não carregada');
      Exit;
    end;

    WriteLn('[GET_PARAM] Chamando ScopeGetParam com TipoParam: ', TipoParam);

    // Limpa a estrutura antes de preencher
    FillChar(ParamColeta, SizeOf(TParamColeta), 0);

    // Chama a função da DLL
    Result := ScopeGetParam(TipoParam, @ParamColeta);

    WriteLn('[GET_PARAM] ScopeGetParam retornou: ', Result);

    if Result = 0 then
    begin
      WriteLn('[GET_PARAM] ✓ Parâmetros obtidos com sucesso');
      WriteLn('[GET_PARAM]   Bandeira: ', ParamColeta.Bandeira);
      WriteLn('[GET_PARAM]   FormatoDado: ', ParamColeta.FormatoDado);
      WriteLn('[GET_PARAM]   HabTeclas: ', ParamColeta.HabTeclas);
      WriteLn('[GET_PARAM]   MsgOp1: ', string(ParamColeta.MsgOp1));
      WriteLn('[GET_PARAM]   MsgOp2: ', string(ParamColeta.MsgOp2));
      WriteLn('[GET_PARAM]   MsgCl1: ', string(ParamColeta.MsgCl1));
      WriteLn('[GET_PARAM]   MsgCl2: ', string(ParamColeta.MsgCl2));
    end
    else
      WriteLn('[GET_PARAM] ✗ Erro ao obter parâmetros. Código: ', Result);

  except
    on E: Exception do
    begin
      WriteLn('[GET_PARAM] Erro: ', E.Message);
      Result := -998;
    end;
  end;
end;

function ResumeParamColeta(Dado: string; Acao: Integer): Integer;
var
  DadoStr: AnsiString;
begin
  Result := -999;

  try
    if not Assigned(ScopeResumeParam) then
    begin
      WriteLn('[RESUME_PARAM] Função ScopeResumeParam não carregada');
      Exit;
    end;

    DadoStr := AnsiString(Dado);

    WriteLn('[RESUME_PARAM] Chamando ScopeResumeParam');
    WriteLn('[RESUME_PARAM]   Dado: "', Dado, '"');
    WriteLn('[RESUME_PARAM]   Acao: ', Acao, ' (0=Próximo, 1=Anterior, 2=Cancelar)');

    // Chama a função da DLL
    Result := ScopeResumeParam(PAnsiChar(DadoStr), Length(DadoStr), Acao);

    WriteLn('[RESUME_PARAM] ScopeResumeParam retornou: ', Result);

    if Result = 0 then
      WriteLn('[RESUME_PARAM] ✓ Parâmetro enviado com sucesso')
    else
      WriteLn('[RESUME_PARAM] ✗ Erro ao enviar parâmetro. Código: ', Result);

  except
    on E: Exception do
    begin
      WriteLn('[RESUME_PARAM] Erro: ', E.Message);
      Result := -998;
    end;
  end;
end;

function GetColetaMessages(TipoParam: Integer): string;
var
  ParamColeta: TParamColeta;
  ResultCode: Integer;
  RealTipoParam: Integer;
  TiposParaTestar: array[0..4] of Integer;
  i: Integer;
  Sucesso: Boolean;
begin
  Result := '';

  try
    // Se o status for 65024 (em andamento), tenta múltiplos TipoParam
    // Se for um código de coleta (64512-64767), usa o próprio código
    if TipoParam = 65024 then
    begin
      // Lista de tipos para tentar quando status é 65024
      TiposParaTestar[0] := 1;     // Tipo padrão para coleta genérica
      TiposParaTestar[1] := 0;     // Tipo 0
      TiposParaTestar[2] := 2;     // Tipo 2
      TiposParaTestar[3] := 64512; // Início do range de coleta
      TiposParaTestar[4] := 64513; // Próximo código de coleta

      Sucesso := False;
      WriteLn('[GET_COLETA_MESSAGES] Status 65024 detectado. Tentando múltiplos TipoParam...');

      for i := 0 to 4 do
      begin
        RealTipoParam := TiposParaTestar[i];
        WriteLn('[GET_COLETA_MESSAGES] Tentativa ', i+1, ': TipoParam = ', RealTipoParam);

        ResultCode := GetParamColeta(RealTipoParam, ParamColeta);

        if ResultCode = 0 then
        begin
          WriteLn('[GET_COLETA_MESSAGES] ✓ Sucesso com TipoParam = ', RealTipoParam);
          Sucesso := True;
          Break;
        end
        else
          WriteLn('[GET_COLETA_MESSAGES] ✗ Falhou com código: ', ResultCode);
      end;

      if not Sucesso then
      begin
        Result := '{"erro":"Nenhum TipoParam funcionou","ultimoCodigo":' + IntToStr(ResultCode) + '}';
        Exit;
      end;
    end
    else
    begin
      // Para códigos de coleta específicos (64512-64767), usa o próprio código
      RealTipoParam := TipoParam;
      WriteLn('[GET_COLETA_MESSAGES] Usando TipoParam: ', RealTipoParam);

      ResultCode := GetParamColeta(RealTipoParam, ParamColeta);

      if ResultCode <> 0 then
      begin
        Result := '{"erro":"Falha ao obter parâmetros","codigo":' + IntToStr(ResultCode) + '}';
        Exit;
      end;
    end;

    // Formata as mensagens em JSON
    Result := '{' +
      '"bandeira":' + IntToStr(ParamColeta.Bandeira) + ',' +
      '"formatoDado":' + IntToStr(ParamColeta.FormatoDado) + ',' +
      '"habTeclas":' + IntToStr(ParamColeta.HabTeclas) + ',' +
      '"msgOp1":"' + string(ParamColeta.MsgOp1) + '",' +
      '"msgOp2":"' + string(ParamColeta.MsgOp2) + '",' +
      '"msgCl1":"' + string(ParamColeta.MsgCl1) + '",' +
      '"msgCl2":"' + string(ParamColeta.MsgCl2) + '",' +
      '"aceitaCartaoDigitado":' + IntToStr(ParamColeta.AceitaCartaoDigitado) + ',' +
      '"tipoParamUsado":' + IntToStr(RealTipoParam) +
      '}';

  except
    on E: Exception do
      Result := '{"erro":"' + E.Message + '"}';
  end;
end;

end.


