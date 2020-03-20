CREATE TABLE COFFEE (
	coffee_id int IDENTITY(1,1) PRIMARY KEY,
	price decimal(5,0) DEFAULT NULL
);
CREATE TABLE INGREDIENTS_ (
	ingredient_id int IDENTITY(1,1) PRIMARY KEY,
	price decimal(5,0) DEFAULT NULL,
	name varchar(128) DEFAULT NULL
);
CREATE TABLE CLIENT (
	client_id int IDENTITY(1,1) PRIMARY KEY,
	fio varchar(128) DEFAULT NULL,
	address varchar(64) DEFAULT NULL,
	birth_date date DEFAULT NULL,
	email varchar(128) DEFAULT NULL,
	phone decimal(11,0) DEFAULT NULL,
	password varchar(32) DEFAULT NULL
);
CREATE TABLE CARRIER (
	carrier_id int IDENTITY(1,1) PRIMARY KEY,
	fio varchar(128) DEFAULT NULL,
	status varchar(64) DEFAULT NULL,
	phone decimal(11,0) DEFAULT NULL
);
CREATE TABLE ORDER_ (
	order_id int IDENTITY(1,1) PRIMARY KEY,
	client_id int FOREIGN KEY REFERENCES CLIENT(client_id),
	carrier_id int FOREIGN KEY REFERENCES CARRIER(carrier_id),
	restaurant_id int NOT NULL,
	status varchar(64) DEFAULT NULL,
	address varchar(64) DEFAULT NULL,
	overall_price decimal(5,0) DEFAULT NULL,
	payment_method varchar(64) DEFAULT NULL
);
CREATE TABLE ORDER_CONTENT (
	order_content_id int IDENTITY(1,1) PRIMARY KEY,
	order_id int FOREIGN KEY REFERENCES ORDER_(order_id),
	coffee_id int FOREIGN KEY REFERENCES COFFEE(coffee_id)
);
CREATE TABLE COFFEE_CONTENT (
	coffee_content_id int IDENTITY(1,1) PRIMARY KEY,
	ingredient_id int FOREIGN KEY REFERENCES INGREDIENTS_(ingredient_id),
	coffee_id int FOREIGN KEY REFERENCES COFFEE(coffee_id)
);


INSERT INTO INGREDIENTS_ (price, name)
VALUES(50, 'Espresso')
INSERT INTO INGREDIENTS_ (price, name)
VALUES(20, 'Water')
INSERT INTO INGREDIENTS_ (price, name)
VALUES(20, 'Milk')
INSERT INTO INGREDIENTS_ (price, name)
VALUES(30, 'Cream')
INSERT INTO INGREDIENTS_ (price, name)
VALUES(15, 'Sugar')
INSERT INTO INGREDIENTS_ (price, name)
VALUES(15, 'cinnamon')

INSERT INTO CARRIER (fio, status, phone)
VALUES ('Petrov Petr Petrovich', 'Available',
'89112223344');


/* Регистрация клиента */
INSERT INTO CLIENT (fio, address, birth_date, email, phone, password) VALUES ('Ivanov Ivan
Ivanovich', 'Pushkin St. 10a', '1990.10.10', 'vasya@gmail.com', '89124442233', '01234567')
/* Составление кофе */
INSERT INTO COFFEE (price) VALUES (0)
INSERT INTO COFFEE_CONTENT (ingredient_id, coffee_id)
VALUES(7, 1)
UPDATE COFFEE SET price = price + (SELECT price FROM INGREDIENTS_ WHERE ingredient_id = 7) WHERE
coffee_id = 1
INSERT INTO COFFEE_CONTENT (ingredient_id, coffee_id)
VALUES(8, 1)
UPDATE COFFEE SET price = price + (SELECT price FROM INGREDIENTS_ WHERE ingredient_id = 8) WHERE
coffee_id = 1
INSERT INTO COFFEE_CONTENT (ingredient_id, coffee_id)
VALUES(10, 1)
UPDATE COFFEE SET price = price + (SELECT price FROM INGREDIENTS_ WHERE ingredient_id = 10) WHERE
coffee_id = 1
GO
/* Составляем заказ */
INSERT INTO ORDER_ (client_id, carrier_id, restaurant_id, status, address, payment_method)
VALUES (2, 1, 3, 'Not paid', 'Pushkin St. 10a', 'Bank Card')
INSERT INTO ORDER_CONTENT (order_id, coffee_id) VALUES(2, 1)
UPDATE ORDER_ SET overall_price = overall_price + (SELECT price FROM COFFEE WHERE
coffee_id = 1) WHERE order_id = 2

go

CREATE PROCEDURE insertClient
	@fio varchar(128),
	@address varchar (64),
	@birth_date date,
	@email varchar(255),
	@phone decimal (11),
	@password varchar(32)
A
	BEGIN
		INSERT into dbo.CLIENT (fio, address, birth_date, email, phone, password)
		values (@fio, @address, @birth_date, @email, @phone, @password)
		RETURN(0)
	END

EXECUTE insertClient @fio='Petrov Petr Maksimovich', @address='Lomonosova st. 13',
@birth_date='1992.11.11', @email='petrP@mail.ru', @phone='89192223300',
@password='qwerty123';

go

CREATE PROCEDURE showSurname
	@fio varchar(128)
AS
	BEGIN
		PRINT(SUBSTRING(@fio, 1, CHARINDEX(' ', @fio)));
	END

go

CREATE FUNCTION showFirstFreeCarrierID()
	RETURNS int
BEGIN
	DECLARE @ans int
	select @ans = (SELECT carrier_id from CARRIER where status LIKE 'Available')
	return @ans
END

go 

CREATE PROCEDURE surnameOfAvailableCarrier
AS
BEGIN
    DECLARE @temp VARCHAR(128)
    select @temp = (SELECT TOP 1 fio from CARRIER where status='Available')
	execute dbo.showSurname @temp
END

-- Dynamic Cursor

go 

CREATE PROCEDURE changeIngredientPrice
	@newIngredientName varchar(128),
	@newPrice decimal(5, 0)
AS
	BEGIN
		DECLARE @ingredient_cursor cursor
		DECLARE @ingredientName varchar(128)
		DECLARE @price decimal(5, 0)
		SET @ingredient_cursor = CURSOR DYNAMIC
		FOR select name, price from INGREDIENTS_
			open @ingredient_cursor
		IF @@CURSOR_ROWS > 0
			FETCH NEXT FROM @ingredient_cursor
			INTO @ingredientName, @price
		WHILE @@FETCH_STATUS = 0
			BEGIN
				IF @ingredientName = @newIngredientName
					UPDATE INGREDIENTS_
				SET price = @newPrice
				WHERE CURRENT OF @ingredient_cursor
				FETCH NEXT FROM @ingredient_cursor
				INTO @ingredientName, @price
			END
		close @ingredient_cursor
		deallocate @ingredient_cursor
	END

exec dbo.changeIngredientPrice @newIngredientName='Filter', @newPrice=80

go

-- Static Cursor

CREATE FUNCTION coffeePriceCounter(@coffee_id int)
	RETURNS decimal(5, 0)
BEGIN
	DECLARE @cost decimal(5, 0) = 0
	DECLARE @ingredient_price decimal(5, 0)
	DECLARE @ingredient_id int
	DECLARE @coffeeID int
	DECLARE @cost_cursor cursor
	SET @cost_cursor = CURSOR STATIC
	FOR
		select ingredient_id, coffee_id from COFFEE_CONTENT
		open @cost_cursor
	if @@CURSOR_ROWS > 0
	begin
		FETCH NEXT FROM @cost_cursor
		INTO @ingredient_id, @coffeeID
		WHILE @@FETCH_STATUS = 0
		begin
			if @coffeeID = @coffee_id
			begin
				select @ingredient_price = (select price from ingredients_ where ingredient_id = @ingredient_id)
				select @cost = @cost + @ingredient_price
			end
			FETCH NEXT FROM @cost_cursor
			INTO @ingredient_id, @coffeeID
		end
		close @cost_cursor
		deallocate @cost_cursor
	end
	return @cost
END


GO


-- Keyset Cursor

CREATE FUNCTION orderPriceCounter(@order_id int)
RETURNS decimal(5, 0)
BEGIN
	DECLARE @cost decimal(5, 0) = 0
	DECLARE @coffee_price decimal(5, 0)
	DECLARE @coffee_id int
	DECLARE @orderID int
	DECLARE @cost_cursor cursor
	SET @cost_cursor = CURSOR KEYSET
	FOR
		select coffee_id, order_id from order_content
		open @cost_cursor
	if @@CURSOR_ROWS > 0
	begin
		FETCH NEXT FROM @cost_cursor
		INTO @coffee_id, @orderID
		WHILE @@FETCH_STATUS = 0
		begin
			if @orderID = @order_id
			begin
				select @coffee_price = (select price from COFFEE where coffee_id = @coffee_id)
				select @cost = @cost + @coffee_price
			end
			FETCH NEXT FROM @cost_cursor
			INTO @coffee_id, @orderID
		end
		close @cost_cursor
		deallocate @cost_cursor
	end
	return @cost
END


GO

CREATE TRIGGER newOrder
	ON [ORDER_] AFTER INSERT
AS
begin
	declare @order_id int
	declare @coffee_id int
	INSERT INTO COFFEE (price) values (0)
	select @order_id=order_id from ORDER_ where order_id=(select max(order_id) from ORDER_)
	select @coffee_id=coffee_id from COFFEE where coffee_id=(select max(coffee_id) from COFFEE)
	insert into ORDER_CONTENT (order_id, coffee_id) values (@order_id, @coffee_id)
end

go


CREATE TRIGGER deleteCoffee
	ON [COFFEE] INSTEAD OF DELETE
AS
begin
	DECLARE @coffee_id int
	SELECT @coffee_id = coffee_id FROM deleted
	DELETE FROM [coffee_content] WHERE coffee_id = @coffee_id
	DELETE FROM [COFFEE] where coffee_id = @coffee_id
end
go


CREATE TRIGGER updateCoffee
	ON [COFFEE] AFTER UPDATE
AS 
IF UPDATE(price)
BEGIN
	DECLARE @priceOld decimal(5, 0)
	DECLARE @priceNew decimal(5, 0)
	DECLARE @order_id int
	DECLARE @coffee_id int
	SELECT @priceOld = (SELECT price FROM deleted)
	SELECT @priceNew = (SELECT price FROM inserted)
	SELECT @coffee_id = (SELECT deleted.coffee_id from deleted)
	SELECT @order_id = (SELECT order_id FROM order_content where coffee_id = @coffee_id)
	UPDATE ORDER_ set overall_price = overall_price + @priceNew - @priceOld where order_id =@order_id
END
go