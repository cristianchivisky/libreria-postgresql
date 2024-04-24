BEGIN;

--PROCEDIMIENTOS

CREATE OR REPLACE FUNCTION ventas_en_un_mes(mes integer, anio integer)
RETURNS SETOF pedido AS
$$
BEGIN
    RETURN QUERY
    SELECT *
    FROM pedido
    WHERE EXTRACT(MONTH FROM fecha) = mes
      AND EXTRACT(YEAR FROM fecha) = anio;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION carrito_de_usuario(id_u text)
RETURNS TABLE (id_carrito INTEGER, isbn INTEGER, titulo VARCHAR(255), precio NUMERIC(10,2), cantidad INTEGER) AS $$
DECLARE
  usuario_carrito INTEGER;
BEGIN
  SELECT u.id_carrito INTO usuario_carrito FROM usuario u WHERE u.id_usuario = id_u;

  RETURN QUERY
  SELECT lc.id_carrito, e.isbn, l.titulo, e.precio, lc.cantidad
  FROM linea_carrito lc
  JOIN ejemplar e ON lc.id_ejemplar = e.isbn
  JOIN libro l ON e.id_libro = l.id_libro
  WHERE lc.id_carrito = usuario_carrito;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION reseñas_usuario(usuario_id text)
RETURNS TABLE (
    libro_id INTEGER,
    libro_titulo VARCHAR(255),
    resenia VARCHAR(1000),
    valoracion INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT r.id_libro, l.titulo, r.texto, r.valoracion
    FROM resenia r
    JOIN libro l ON r.id_libro = l.id_libro
    WHERE r.id_usuario = usuario_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION obtener_libros_usuario(id_usuario_texto TEXT)
RETURNS TABLE (
  titulo_libro VARCHAR(255),
  isbn_ejemplar  INTEGER,
  cantidad_comprada INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    l.titulo,
    e.isbn,
    lp.cantidad
  FROM
    linea_pedido lp
  INNER JOIN
    ejemplar e ON lp.id_ejemplar = e.isbn
  INNER JOIN
    libro l ON e.id_libro = l.id_libro
  INNER JOIN
    pedido p ON lp.id_pedido = p.id_pedido
  WHERE
    p.id_usuario = id_usuario_texto;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION usuario_pedidos(usuario_id text)
RETURNS TABLE (
    pedido_id INTEGER,
    fecha_pedido TIMESTAMP,
    costo_envio NUMERIC(10,2),
    costo_total NUMERIC(10,2),
    costo_total_con_descuento NUMERIC(10,2), 
    direccion_envio INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT p.id_pedido, p.fecha, p.costo_envio, p.total, p.total_con_descuento, p.id_direccion
    FROM pedido p
    JOIN linea_pedido lp ON p.id_pedido = lp.id_pedido
    WHERE p.id_usuario = usuario_id
    GROUP BY p.id_pedido, p.fecha, p.total;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION costo_total_carrito(p_id_usuario TEXT)
RETURNS TABLE (total_con_descuento NUMERIC, monto_descontado NUMERIC) AS $$
DECLARE
    total_pedido NUMERIC(10,2);
    descuento_promocion NUMERIC(10,2);
    monto_descontado NUMERIC(10,2);
BEGIN
    -- Calcula el total sin descuento
    SELECT SUM(ejemplar.precio * linea_carrito.cantidad)
    INTO total_pedido
    FROM linea_carrito
    JOIN ejemplar ON linea_carrito.id_ejemplar = ejemplar.isbn
    WHERE linea_carrito.id_carrito = (SELECT id_carrito FROM usuario WHERE usuario.id_usuario = p_id_usuario);
 
    -- Verificar si hay descuentos de promoción
    SELECT COALESCE(SUM(promocion_descuento.porcentaje * ejemplar.precio * linea_carrito.cantidad / 100), 0)
    INTO descuento_promocion
    FROM linea_carrito
    JOIN ejemplar ON linea_carrito.id_ejemplar = ejemplar.isbn
    LEFT JOIN ejemplar_promocion ON ejemplar.isbn = ejemplar_promocion.id_ejemplar
    LEFT JOIN promocion_descuento ON ejemplar_promocion.id_promocion_descuento = promocion_descuento.id_promocion_descuento
    WHERE linea_carrito.id_carrito = (SELECT id_carrito FROM usuario WHERE usuario.id_usuario = p_id_usuario)
      AND promocion_descuento.fecha_inicio <= CURRENT_TIMESTAMP
      AND promocion_descuento.fecha_fin >= CURRENT_TIMESTAMP;

    total_pedido := total_pedido - descuento_promocion;

    -- Calcula el monto descontado
    monto_descontado := descuento_promocion;

    RETURN QUERY SELECT total_pedido, monto_descontado;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION obtener_resenas_libro(libro_id INTEGER)
RETURNS TABLE (
  nombre_usuario VARCHAR(255),
  texto_resena VARCHAR(1000),
  valoracion INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.nombre,
    r.texto,
    r.valoracion
  FROM
    resenia r
  INNER JOIN
    usuario u ON r.id_usuario = u.id_usuario
  WHERE
    r.id_libro = libro_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION obtener_cantidad_y_total_ventas_mes(anio INTEGER, mes INTEGER)
RETURNS TABLE(total_cantidad BIGINT, total_ventas NUMERIC(10,2)) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(SUM(lp.cantidad), 0) AS total_cantidad,
    COALESCE(SUM(p.total_con_descuento), 0.00) AS total_ventas
  FROM
    linea_pedido lp
  INNER JOIN
    pedido p ON lp.id_pedido = p.id_pedido
  WHERE
    EXTRACT(YEAR FROM p.fecha) = anio
    AND EXTRACT(MONTH FROM p.fecha) = mes;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION obtener_usuarios_ciudad(codigo_postal INTEGER)
RETURNS TABLE (
  nombre_usuario VARCHAR(255),
  email_usuario VARCHAR(255)
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.nombre,
    u.email
  FROM
    usuario u
  INNER JOIN
    direccion d ON u.id_usuario = d.id_usuario
  WHERE
    d.cp_ciudad = codigo_postal;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION obtener_libros_favoritos_usuario(id_usuario_texto TEXT)
RETURNS TABLE (
  titulo_libro VARCHAR(255)
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    l.titulo
  FROM
    favorito_libro fl
  INNER JOIN
    libro l ON fl.id_libro = l.id_libro
  WHERE
    fl.id_usuario = id_usuario_texto;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION obtener_libros_deseados_usuario(id_usuario_texto TEXT)
RETURNS TABLE (
  titulo_libro VARCHAR(255)
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    l.titulo
  FROM
    deseo_libro dl
  INNER JOIN
    libro l ON dl.id_libro = l.id_libro
  WHERE
    dl.id_usuario = id_usuario_texto;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION obtener_libros_mas_vendidos(anio INTEGER, mes INTEGER)
RETURNS TABLE(libro_id INTEGER, titulo VARCHAR(255), cantidad_vendida BIGINT) AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.id_libro,
    l.titulo,
    COALESCE(SUM(lp.cantidad), 0) AS total_cantidad
  FROM
    linea_pedido lp
  INNER JOIN
    pedido p ON lp.id_pedido = p.id_pedido
  INNER JOIN
    ejemplar e ON lp.id_ejemplar = e.isbn
  INNER JOIN
    libro l ON e.id_libro = l.id_libro
  WHERE
    EXTRACT(YEAR FROM p.fecha) = anio
    AND EXTRACT(MONTH FROM p.fecha) = mes
  GROUP BY
    e.id_libro, l.titulo
  ORDER BY
    total_cantidad DESC
  LIMIT 10;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION libros_por_autor(autor_id integer)
RETURNS TABLE (titulo VARCHAR, autor VARCHAR, genero VARCHAR, descripcion VARCHAR) AS $$
BEGIN
  RETURN QUERY
  SELECT
    libro.titulo,
    autor.nombre_autor AS autor,
	genero.nombre_genero,
    libro.descripcion AS descripcion
  FROM
    libro
    INNER JOIN libro_autor ON libro.id_libro = libro_autor.id_libro
    INNER JOIN autor ON libro_autor.id_autor = autor.id_autor
	INNER JOIN libro_genero ON libro.id_libro = libro_genero.id_libro
    INNER JOIN genero ON libro_genero.id_genero = genero.id_genero
  WHERE
    autor.id_autor = autor_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION libros_por_genero(genero_id INTEGER)
RETURNS TABLE (titulo VARCHAR, autor VARCHAR, genero VARCHAR, descripcion VARCHAR) AS $$
BEGIN
  RETURN QUERY
  SELECT
    libro.titulo,
    autor.nombre_autor AS autor,
    genero.nombre_genero AS genero,
	libro.descripcion
  FROM
    libro
    INNER JOIN libro_autor ON libro.id_libro = libro_autor.id_libro
    INNER JOIN autor ON libro_autor.id_autor = autor.id_autor
    INNER JOIN libro_genero ON libro.id_libro = libro_genero.id_libro
    INNER JOIN genero ON libro_genero.id_genero = genero.id_genero
  WHERE
    genero.id_genero = genero_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION informacion_libro_por_titulo(p_titulo VARCHAR)
RETURNS TABLE (titulo VARCHAR, autor VARCHAR, genero VARCHAR, ISBN INTEGER, precio NUMERIC) AS $$
BEGIN
  RETURN QUERY
  SELECT
    libro.titulo,
    autor.nombre_autor AS autor,
    genero.nombre_genero AS genero,
    ejemplar.isbn,
    ejemplar.precio
  FROM
    libro
    INNER JOIN libro_autor ON libro.id_libro = libro_autor.id_libro
    INNER JOIN autor ON libro_autor.id_autor = autor.id_autor
    INNER JOIN libro_genero ON libro.id_libro = libro_genero.id_libro
    INNER JOIN genero ON libro_genero.id_genero = genero.id_genero
    INNER JOIN ejemplar ON libro.id_libro = ejemplar.id_libro
  WHERE
    libro.titulo = p_titulo;
END;
$$ LANGUAGE plpgsql;

-- VISTAS

CREATE VIEW vista_libros_resenias AS
SELECT l.titulo, AVG(resenia.valoracion) AS promedio_resenia, COUNT(resenia.valoracion) AS cantidad_resenias
FROM libro l
LEFT JOIN resenia ON l.id_libro = resenia.id_libro
GROUP BY l.id_libro, l.titulo;


CREATE OR REPLACE VIEW ejemplares_sin_stock AS
SELECT
  l.titulo,
  e.isbn,
  e.precio,
  e.id_editorial,
  e.id_encuadernado
FROM
  ejemplar e
INNER JOIN
  libro l ON e.id_libro = l.id_libro
WHERE
  e.stock = 0;


CREATE OR REPLACE VIEW vista_inventario AS
SELECT
  e.isbn,
  l.titulo,
  e.precio,
  e.stock,
  l.descripcion,
  en.tipo,
  ed.nombre_editorial
FROM
  libro l 
  JOIN ejemplar e ON l.id_libro = e.id_libro
  JOIN encuadernado en ON e.id_encuadernado = en.id_encuadernado
  JOIN editorial ed ON ed.id_editorial = e.id_editorial;

CREATE OR REPLACE VIEW vista_pedidos_recientes AS
SELECT
  id_pedido,
  fecha,
  total,
  total_con_descuento
FROM
  pedido
ORDER BY
  fecha DESC
LIMIT 10;

CREATE OR REPLACE VIEW vista_ejemplares_en_promocion AS
SELECT
  l.id_libro,
  l.titulo,
  e.isbn,
  p.nombre_promocion,
  p.porcentaje
FROM
  ejemplar_promocion ep
INNER JOIN
  ejemplar e ON ep.id_ejemplar = e.isbn
INNER JOIN
  libro l ON e.id_libro = l.id_libro
INNER JOIN
  promocion_descuento p ON ep.id_promocion_descuento = p.id_promocion_descuento
WHERE
  p.fecha_inicio <= CURRENT_TIMESTAMP AND p.fecha_fin >= CURRENT_TIMESTAMP;

CREATE OR REPLACE VIEW vista_promociones_vigentes AS
SELECT
  pd.id_promocion_descuento,
  pd.nombre_promocion,
  pd.porcentaje,
  pd.fecha_inicio,
  pd.fecha_fin
FROM
  promocion_descuento pd
WHERE
  pd.fecha_inicio <= CURRENT_TIMESTAMP AND pd.fecha_fin >= CURRENT_TIMESTAMP;

CREATE OR REPLACE VIEW vista_usuarios_cantidad_comprada AS
SELECT
  u.id_usuario,
  u.nombre,
  u.apellido,
  sum(lp.cantidad) AS cantidad_comprada
FROM
  usuario u
LEFT JOIN
  pedido p ON u.id_usuario = p.id_usuario
LEFT JOIN
  linea_pedido lp ON p.id_pedido = lp.id_pedido
GROUP BY
  u.id_usuario, u.nombre, u.apellido;


COMMIT;

