BEGIN;

--La función crear_carrito() se ejecutará como un disparador antes de 
--insertar un nuevo usuario en la tabla usuario. Esta función crea un nuevo carrito y asigna su 
--ID al nuevo usuario.

CREATE OR REPLACE FUNCTION crear_carrito() RETURNS TRIGGER AS $funcemp$
DECLARE
carrito_id integer;
BEGIN
	INSERT INTO carrito DEFAULT VALUES RETURNING id_carrito INTO carrito_id;
	NEW.id_carrito = carrito_id;
RETURN NEW;
END; $funcemp$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_carrito BEFORE INSERT ON usuario
FOR EACH ROW EXECUTE PROCEDURE crear_carrito();

--La función validar_fechas_promocion() se ejecutará como un disparador antes de insertar o 
--actualizar una fila en la tabla promocion_descuento. Esta función valida que las fechas de 
--inicio y fin de una promoción sean coherentes.

CREATE OR REPLACE FUNCTION validar_fechas_promocion()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.fecha_inicio < NOW() THEN
    RAISE EXCEPTION 'La fecha de inicio debe ser mayor que la fecha actual';
  END IF;

  IF NEW.fecha_fin <= NEW.fecha_inicio THEN
    RAISE EXCEPTION 'La fecha de fin debe ser mayor que la fecha de inicio';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER controlar_fechas_promocion
BEFORE INSERT OR UPDATE
ON promocion_descuento
FOR EACH ROW
EXECUTE FUNCTION validar_fechas_promocion();

-- Este trigger asegura que una reseña solo puede ser agregada por un usuario que ha
-- comprado el libro correspondiente.

CREATE OR REPLACE FUNCTION controlar_resenia()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM linea_pedido lp
    JOIN pedido p ON lp.id_pedido = p.id_pedido
    JOIN ejemplar e ON lp.id_ejemplar = e.isbn
    JOIN libro l ON e.id_libro = l.id_libro
    WHERE p.id_usuario = NEW.id_usuario AND l.id_libro = NEW.id_libro
  ) THEN
    RETURN NEW;
  ELSE
    RAISE EXCEPTION 'No se puede agregar una reseña sin haber comprado el libro';
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_control_resenia
BEFORE INSERT
ON resenia
FOR EACH ROW
EXECUTE FUNCTION controlar_resenia();

-- Este trigger asegura que haya suficiente stock antes de realizar una venta.

CREATE OR REPLACE FUNCTION controlar_stock_venta()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.cantidad > (SELECT stock FROM ejemplar WHERE isbn = NEW.id_ejemplar) THEN
    RAISE EXCEPTION 'No hay suficiente stock para realizar la venta';
  ELSE
    UPDATE ejemplar
    SET stock = stock - NEW.cantidad
    WHERE isbn = NEW.id_ejemplar;
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_control_stock_venta
BEFORE INSERT
ON linea_pedido
FOR EACH ROW
EXECUTE FUNCTION controlar_stock_venta();

--Este trigger se encarga de trasladar las líneas del carrito a la tabla de pedidos 
--cuando se realiza una venta.

CREATE OR REPLACE FUNCTION pasar_carrito_a_pedido()
RETURNS TRIGGER AS $$
DECLARE
  id_car INTEGER;
  id_ped INTEGER = NEW.id_pedido;
  linea_carrito_aux RECORD;
BEGIN
  SELECT id_carrito INTO id_car FROM usuario WHERE id_usuario = NEW.id_usuario;

  FOR linea_carrito_aux IN (SELECT lc.*, e.precio
                           FROM linea_carrito lc
                           JOIN ejemplar e ON lc.id_ejemplar = e.isbn
                           WHERE lc.id_carrito = id_car)
  LOOP
    INSERT INTO linea_pedido (id_pedido, id_ejemplar, cantidad, precio)
    VALUES (id_ped, linea_carrito_aux.id_ejemplar, linea_carrito_aux.cantidad, linea_carrito_aux.precio);
  END LOOP;

  DELETE FROM linea_carrito WHERE id_carrito = id_car;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_pasar_carrito_a_pedido
AFTER INSERT
ON pedido
FOR EACH ROW
EXECUTE FUNCTION pasar_carrito_a_pedido();

-- Este trigger se ejecutara despues de cada actualizacion en la tabla ejemplar, 
-- Si el nuevo stock es mayor que el antiguo, se inserta una nueva linea en la tabla notificacion 
--indicando que se repuso el stock.

CREATE OR REPLACE FUNCTION generar_notificacion_reposicion()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND (NEW.stock > OLD.stock) THEN
    INSERT INTO reposicion (id_ejemplar, stock_incorporado)
    VALUES (NEW.isbn, (NEW.stock - OLD.stock));
  ELSIF TG_OP = 'INSERT' THEN
    INSERT INTO reposicion (id_ejemplar, stock_incorporado)
    VALUES (NEW.isbn, NEW.stock);
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notificacion_reposicion
AFTER INSERT OR UPDATE
ON ejemplar
FOR EACH ROW
EXECUTE FUNCTION generar_notificacion_reposicion();



-- Este trigger no permite que se modifique un pedido.

CREATE OR REPLACE FUNCTION no_modificacion_pedido()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'No se permite la modificación en la tabla pedido.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_no_modificacion_pedido
BEFORE UPDATE ON pedido
FOR EACH ROW
EXECUTE FUNCTION no_modificacion_pedido();

-- Este no permite la modificación ni la eliminación de las lineas de pedido.

CREATE OR REPLACE FUNCTION no_modificacion_eliminacion_linea_pedido()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'No se permite la modificación en la tabla linea_pedido.';
  ELSIF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'No se permite la eliminación en la tabla linea_pedido.';
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_no_modificacion_eliminacion_linea_pedido
BEFORE UPDATE OR DELETE ON linea_pedido
FOR EACH ROW
EXECUTE FUNCTION no_modificacion_eliminacion_linea_pedido();

-- Evita la inserción de líneas de carrito para ejemplares con stock cero.

CREATE OR REPLACE FUNCTION verificar_stock_antes_insertar()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.cantidad > 0 AND (SELECT stock FROM ejemplar WHERE isbn = NEW.id_ejemplar) = 0 THEN
        RAISE EXCEPTION 'No hay suficiente stock.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevenir_insercion_stock_cero
BEFORE INSERT ON linea_carrito
FOR EACH ROW
EXECUTE FUNCTION verificar_stock_antes_insertar();


--  Verifica si el stock del ejemplar se actualiza a cero, si es así,
-- elimina las líneas de carrito asociadas con ese id_ejemplar. 

CREATE OR REPLACE FUNCTION verificar_stock_despues_actualizar()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.stock = 0 AND OLD.stock > 0 THEN
        DELETE FROM linea_carrito WHERE id_ejemplar = NEW.isbn;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER controlar_stock_carrito
AFTER UPDATE ON ejemplar
FOR EACH ROW
EXECUTE FUNCTION verificar_stock_despues_actualizar();

COMMIT;

