-- Isabella Santos Veras
/*
Hamburgueria xTopBurguer: Tabelas Principais

    Cliente: Armazena informações sobre os clientes.

    Produto: Cadastra os produtos vendidos pela hamburgueria (hambúrgueres, batatas, refrigerantes, etc.).

    Pedido: Registra os pedidos feitos pelos clientes.

    ItemPedido: Relaciona pedidos com produtos.

    Caixa: Registra as transações financeiras diárias.
 
*/
CREATE SCHEMA HAMBURGUERIA_XTOPBURGUER;
USE HAMBURGUERIA_XTOPBURGUER;
-- Tabela Cliente
CREATE TABLE Cliente (
    id_cliente INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL,
    telefone VARCHAR(15) NOT NULL,
    endereco VARCHAR(255) NOT NULL
);

-- Tabela Produto
CREATE TABLE Produto (
    id_produto INT PRIMARY KEY AUTO_INCREMENT,
    descricao VARCHAR(100) NOT NULL,
    preco_custo DECIMAL(10, 2) DEFAULT 0,
    preco_venda DECIMAL(10, 2) DEFAULT 0,
    estoque int Not null
);

-- Produtos
INSERT INTO Produto (descricao,preco_custo, preco_venda,estoque) VALUES
('xTop Simples',10, 15.00,12),
('xTop Duplo',13, 25.00,23),
('xTop Bacon',18, 31.00,22),
('xTop Tudo',22, 45.00,29),
('xTop Vegano', 29,40.00,18),
('Batata Frita P',4, 8.00,50),
('Batata Frita M',7, 12.00,60),
('Batata Frita G',12, 18.00,45),
('Refrigerante Lata',3, 8.00,90),
('Refrigerante 1L',6, 11.00,45),
('Refrigerante 2L',8, 15.00,33);
-- Tabela Pedido
CREATE TABLE Pedido (
    id_pedido INT PRIMARY KEY AUTO_INCREMENT,
    id_cliente INT NOT NULL,
    data_pedido DATE NOT NULL,
    hora_pedido TIME NOT NULL,
    FOREIGN KEY (id_cliente) REFERENCES Cliente(id_cliente)
);

-- Tabela ItemPedido
CREATE TABLE ItemPedido (
    id_item INT PRIMARY KEY AUTO_INCREMENT,
    id_pedido INT NOT NULL,
    id_produto INT NOT NULL,
    quantidade INT NOT NULL DEFAULT 1,
    FOREIGN KEY (id_pedido) REFERENCES Pedido(id_pedido),
    FOREIGN KEY (id_produto) REFERENCES Produto(id_produto)
);


-- Tabela Caixa
CREATE TABLE Caixa (
    id_caixa INT PRIMARY KEY AUTO_INCREMENT,
    data DATE NOT NULL,
    entrada DECIMAL(15, 2) DEFAULT 0,
    saida DECIMAL(15, 2) DEFAULT 0,
    saldo DECIMAL(15, 2) NOT NULL
);

-- Inserção de dados de exemplo

-- Clientes
INSERT INTO Cliente (nome, telefone, endereco) VALUES
('João Silva', '11987654321', 'Rua das Flores, 123'),
('Maria Souza', '11912345678', 'Avenida Brasil, 456'),
('Carlos Oliveira', '11955554444', 'Rua das Palmeiras, 789'),
('Janule Oliveira', '44333334555', 'Rua das casas, 79'),
('Teclaudio Gomes', '12344232222', 'Rua das hortaliças, 78');


-- Pedidos
INSERT INTO Pedido (id_cliente, data_pedido, hora_pedido) VALUES
(1, '2025-10-23', '18:30:00'),
(2, '2025-10-23', '19:15:00'),
(3, '2025-10-23', '20:00:00'),
(4, '2025-10-23', '19:15:00'),
(5, '2025-10-23', '20:15:00');

-- Itens dos Pedidos
INSERT INTO ItemPedido (id_pedido, id_produto, quantidade) VALUES
(1, 1, 1),
(1, 2, 1),
(2, 3, 2),
(3, 4, 1),
(4, 4, 1),
(4, 5, 1),
(4, 7, 1),
(4, 7, 1),
(4, 10, 1),
(5, 5, 1),
(5, 8, 1),
(5, 9, 1);

/*
1. Trigger para controlar estoque antes de inserir item no pedido
Antes de inserir um item em ItemPedido, verifica se o estoque do produto 
é suficiente para a quantidade solicitada. Se não for, 
aborta a inserção com erro. Caso positivo, 
atualiza o estoque subtraindo a quantidade.
*/
DELIMITER //

CREATE TRIGGER trg_itempedido_before_insert
BEFORE INSERT ON ItemPedido
FOR EACH ROW
BEGIN
  DECLARE estoque_atual INT;

  SELECT estoque INTO estoque_atual FROM Produto WHERE id_produto = NEW.id_produto;

  IF estoque_atual IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Produto não encontrado.';
  ELSEIF estoque_atual < NEW.quantidade THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Estoque insuficiente para o produto.';
  ELSE
    UPDATE Produto SET estoque = estoque - NEW.quantidade WHERE id_produto = NEW.id_produto;
  END IF;
END;
//

DELIMITER ;

/*
2. Trigger para restaurar estoque após remoção de item do pedido
Após deletar um item de pedido, repõe a quantidade do produto no estoque.
*/
DELIMITER //
CREATE TRIGGER trg_itempedido_after_delete
AFTER DELETE ON ItemPedido
FOR EACH ROW
BEGIN
  UPDATE Produto
  SET estoque = estoque + OLD.quantidade
  WHERE id_produto = OLD.id_produto;
END //
DELIMITER ;


/*
Crie uma trigger chamada trg_itempedido_atualiza_caixa que seja executada APÓS a inserção de um registro na tabela ItemPedido. 
Esta trigger deve:
    Buscar a data do pedido relacionado ao item inserido (consultando a tabela Pedido).
    Calcular o valor do item multiplicando o preço de venda do produto pela quantidade inserida (consultando a tabela Produto).
    Verificar se já existe um registro no caixa para a data do pedido:
        Se NÃO existir: Inserir um novo registro na tabela Caixa com:
 - `data` = data do pedido
 - `entrada` = valor do item
 - `saida` = 0
 - `saldo` = valor do item
    Se EXISTIR: Atualizar o registro existente, somando o valor do item às colunas entrada e saldo.
    Caso a data do pedido não seja encontrada (por algum erro), usar a data atual (CURDATE()).
*/

-- Primeiro, remova a trigger antiga
DROP TRIGGER IF EXISTS trg_itempedido_atualiza_caixa;

DELIMITER //

CREATE TRIGGER trg_itempedido_atualiza_caixa
AFTER INSERT ON ItemPedido
FOR EACH ROW
BEGIN
  DECLARE v_valor_item DECIMAL(15,2);
  DECLARE v_data_pedido DATE;
  DECLARE v_caixa_existe INT DEFAULT 0;

  -- Busca a data do pedido relacionado ao item
  SELECT p.data_pedido 
  INTO v_data_pedido 
  FROM Pedido p
  WHERE p.id_pedido = NEW.id_pedido;
  
  -- Calcula o valor do item inserido
  SELECT pr.preco_venda * NEW.quantidade
  INTO v_valor_item
  FROM Produto pr
  WHERE pr.id_produto = NEW.id_produto;

  -- Se não encontrou a data do pedido, usa a data atual
  IF v_data_pedido IS NULL THEN
    SET v_data_pedido = CURDATE();
  END IF;

  -- Verifica se já existe registro no caixa para ESSA DATA ESPECÍFICA
  SELECT COUNT(*) 
  INTO v_caixa_existe 
  FROM Caixa 
  WHERE data = v_data_pedido;

  IF v_caixa_existe = 0 THEN
    -- NÃO EXISTE: Insere novo registro no caixa para essa data
    INSERT INTO Caixa (data, entrada, saida, saldo) 
    VALUES (v_data_pedido, v_valor_item, 0, v_valor_item);
  ELSE
    -- EXISTE: Atualiza APENAS a linha da data específica
    UPDATE Caixa
    SET entrada = entrada + v_valor_item,
        saldo = saldo + v_valor_item
    WHERE data = v_data_pedido;
  END IF;
END;
//

DELIMITER ;


-- 1. Insira o pedido
INSERT INTO Pedido (id_cliente, data_pedido, hora_pedido) 
VALUES (1, '2025-10-26', CURTIME());

-- 2. Verifique o ID
SELECT LAST_INSERT_ID() AS id_pedido;

-- 3. Insira um item (use o ID correto do pedido)
INSERT INTO ItemPedido (id_pedido, id_produto, quantidade) 
VALUES 
(6, 1, 1),
(6, 1, 1);
-- 4. Verifique o caixa
SELECT * FROM Caixa WHERE data = CURDATE();
SELECT * FROM Caixa;

-- Atividade AQUI
-- 1 Trigger : Garantir que o preço de venda seja sempre maior que o preço de custo (evitando prejuízos acidentais). Executado antes de qualquer UPDATE em Produto.
DELIMITER //

CREATE TRIGGER trg_produto_before_update_validacao
BEFORE UPDATE ON Produto
FOR EACH ROW
BEGIN
  IF NEW.preco_venda <= NEW.preco_custo THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Preço de venda deve ser maior que o preço de custo.';
  END IF;
-- Não permite que o estoque fique negativo
  IF NEW.estoque < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Estoque não pode ser negativo.';
  END IF;
END;
//
DELIMITER ;

Select * from produto where id_produto = 1;
UPDATE Produto SET preco_venda = 5 WHERE id_produto = 1;

-- 2 Trigger : Protege pedidos com mais de 30 dias contra exclusão acidental, mantendo o histórico. Executado antes de DELETE em Pedido.
DELIMITER //

CREATE TRIGGER trg_pedido_before_delete_impede_antigos
BEFORE DELETE ON Pedido
FOR EACH ROW
BEGIN
  -- Impede delete se o pedido tiver mais de 30 dias
  IF OLD.data_pedido < DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Não é possível excluir pedidos com mais de 30 dias.';
  END IF;
END;
//

DELIMITER ;

Select * from pedido where id_pedido = 1;
DELETE FROM Pedido WHERE id_pedido = 1;

-- 3 Trigger: Garantir que os pedidos não sejam feitos fora do horário de funcionamento (ex.: após as 22h00), evitando operações inválidas. Executado antes de INSERT em Pedido.


DELIMITER //

CREATE TRIGGER trg_pedido_before_insert_horario_limite
BEFORE INSERT ON Pedido
FOR EACH ROW
BEGIN
  -- Define o horário limite (22:00:00); ajuste conforme necessário
  DECLARE horario_limite TIME DEFAULT '22:00:00';
  
  -- Verifica se a hora do pedido é posterior ao limite
  IF NEW.hora_pedido > horario_limite THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Pedidos não são permitidos após as 22:00.';
  END IF;
END;
//

DELIMITER ;
-- 4 Trigger :  Ela verifica se o estoque do produto ficou menor ou igual a 10 e insere um registro na tabela auxiliar Alerta_Estoque para envio.ELe é útil para alertar sobre a necessidade de reabastecimento.
-- Tabela auxiliar:
CREATE TABLE Alerta_Estoque (
    id_alerta INT PRIMARY KEY AUTO_INCREMENT,
    id_produto INT,
    descricao_produto VARCHAR(100),
    estoque_atual INT,
    data_alerta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_produto) REFERENCES Produto(id_produto)
);
-- Trigger:
DELIMITER //

CREATE TRIGGER trg_itempedido_after_insert_alerta_estoque
AFTER INSERT ON ItemPedido
FOR EACH ROW
BEGIN
  DECLARE v_estoque_atual INT;
  DECLARE v_descricao VARCHAR(100);
  
  -- Busca o estoque atual e descrição após a redução
  SELECT estoque, descricao 
  INTO v_estoque_atual, v_descricao 
  FROM Produto 
  WHERE id_produto = NEW.id_produto;
  
  -- Se estoque <= 10, insere alerta
  IF v_estoque_atual <= 10 THEN
    INSERT INTO Alerta_Estoque (id_produto, descricao_produto, estoque_atual)
    VALUES (NEW.id_produto, v_descricao, v_estoque_atual);
  END IF;
END;
//

DELIMITER ;

iNSERT INTO ItemPedido (id_pedido, id_produto, quantidade) VALUES (1, 1, 5);
SELECT * FROM Alerta_Estoque;


-- 5 Trigger ele é xecutado antes de INSERT ou UPDATE em Cliente, verificando se o telefone já existe para outro cliente. Se sim, aborte a operação com erro, evitando duplicidade.

DELIMITER //

CREATE TRIGGER trg_cliente_before_insert_update_telefone_unico
BEFORE INSERT ON Cliente
FOR EACH ROW
BEGIN
  DECLARE telefone_existe INT DEFAULT 0;
  
  -- Verifica se o telefone já existe (excluindo o próprio registro em updates)
  SELECT COUNT(*) INTO telefone_existe 
  FROM Cliente 
  WHERE telefone = NEW.telefone AND id_cliente != COALESCE(NEW.id_cliente, 0);
  
  IF telefone_existe > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Telefone já cadastrado para outro cliente.';
  END IF;
END;
//

DELIMITER ;

INSERT INTO Cliente (nome, telefone, endereco) VALUES ('Novo Cliente', '11987654321', 'Rua Nova, 123');  /*retornar erro*/
INSERT INTO Cliente (nome, telefone, endereco) VALUES ('Novo Cliente', '11999999999', 'Rua Nova, 123'); /* vai deixar cadastrar*/