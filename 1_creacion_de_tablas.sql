BEGIN;

CREATE TABLE carrito (
  id_carrito SERIAL PRIMARY KEY
);

CREATE TABLE usuario (
  id_usuario text PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  apellido VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  imagen text,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
  rol CHAR(1) DEFAULT '2' NOT NULL CHECK(rol='1' or rol='2'),
  id_carrito integer NOT NULL REFERENCES carrito(id_carrito) ON UPDATE CASCADE
);

CREATE TABLE ciudad (
  cp INTEGER NOT NULL PRIMARY KEY,
  nombre_ciudad VARCHAR(255) NOT NULL
);

CREATE TABLE direccion (
  id_direccion SERIAL PRIMARY KEY,
  calle VARCHAR(255) NOT NULL,
  numero INTEGER NOT NULL,
  id_usuario text NOT NULL REFERENCES usuario (id_usuario) ON UPDATE CASCADE,
  cp_ciudad INTEGER NOT NULL REFERENCES ciudad (cp) ON UPDATE CASCADE
);

CREATE TABLE editorial (
  id_editorial SERIAL PRIMARY KEY,
  nombre_editorial VARCHAR(255) UNIQUE NOT NULL
);

CREATE TABLE encuadernado (
  id_encuadernado SERIAL PRIMARY KEY,
  tipo VARCHAR(255) UNIQUE NOT NULL
);

CREATE TABLE libro (
  id_libro SERIAL PRIMARY KEY,
  titulo VARCHAR(255) NOT NULL,
  descripcion VARCHAR(1000) NOT NULL,
  imagen text
);

CREATE TABLE ejemplar (
  isbn INTEGER NOT NULL PRIMARY KEY,
  precio NUMERIC(10,2) NOT NULL CHECK (precio > 0),
  stock INTEGER NOT NULL CHECK (stock >= 0),
  dimensiones VARCHAR(225) NOT NULL,
  paginas INTEGER NOT NULL CHECK (paginas > 0),
  id_libro INTEGER NOT NULL REFERENCES libro (id_libro) ON UPDATE CASCADE,
  id_editorial INTEGER NOT NULL REFERENCES editorial (id_editorial) ON UPDATE CASCADE,
  id_encuadernado INTEGER NOT NULL REFERENCES encuadernado (id_encuadernado) ON UPDATE CASCADE
);

CREATE TABLE autor (
  id_autor SERIAL PRIMARY KEY,
  nombre_autor VARCHAR(255) UNIQUE NOT NULL
);

CREATE TABLE libro_autor (
  id_libro INTEGER NOT NULL REFERENCES libro (id_libro) ON UPDATE CASCADE,
  id_autor INTEGER NOT NULL REFERENCES autor (id_autor) ON UPDATE CASCADE,
  CONSTRAINT id_libro_autor PRIMARY KEY(id_libro, id_autor)
);

CREATE TABLE genero (
  id_genero SERIAL PRIMARY KEY,
  nombre_genero VARCHAR(255) UNIQUE NOT NULL
);

CREATE TABLE libro_genero (
  id_libro INTEGER NOT NULL REFERENCES libro (id_libro) ON UPDATE CASCADE,
  id_genero INTEGER NOT NULL REFERENCES genero (id_genero) ON UPDATE CASCADE,
  CONSTRAINT id_libro_genero PRIMARY KEY(id_libro, id_genero)
);

CREATE TABLE favorito_libro (
  id_usuario text NOT NULL REFERENCES usuario (id_usuario) ON UPDATE CASCADE,
  id_libro INTEGER NOT NULL REFERENCES libro (id_libro) ON UPDATE CASCADE,
  CONSTRAINT id_favorito_libro PRIMARY KEY(id_usuario, id_libro)
);

CREATE TABLE deseo_libro (
  id_usuario text NOT NULL REFERENCES usuario (id_usuario) ON UPDATE CASCADE,
  id_libro INTEGER NOT NULL REFERENCES libro (id_libro) ON UPDATE CASCADE,
  CONSTRAINT id_deseo_libro PRIMARY KEY(id_usuario, id_libro)
);

CREATE TABLE resenia (
  texto VARCHAR(1000) NOT NULL,
  valoracion INTEGER CHECK (valoracion >= 1 AND valoracion <= 5) NOT NULL,
  id_usuario text NOT NULL REFERENCES usuario (id_usuario) ON UPDATE CASCADE,
  id_libro INTEGER NOT NULL REFERENCES libro (id_libro) ON UPDATE CASCADE,
  CONSTRAINT   id_resenia PRIMARY KEY(id_usuario, id_libro)
);

CREATE TABLE tipo_envio (
  id_tipo_envio SERIAL  PRIMARY KEY,
  descripcion VARCHAR(225) UNIQUE NOT NULL
);

CREATE TABLE pedido (
  id_pedido SERIAL PRIMARY KEY,
  id_envio INTEGER NOT NULL REFERENCES tipo_envio (id_tipo_envio) ON UPDATE CASCADE,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL, 
  costo_envio NUMERIC(10,2) NOT NULL CHECK(costo_envio >= 0),
  total NUMERIC(10,2) NOT NULL CHECK(total >= 0.0),
  total_con_descuento NUMERIC(10,2) NOT NULL CHECK(total_con_descuento >= 0.0),
  id_usuario text NOT NULL REFERENCES usuario(id_usuario) ON UPDATE CASCADE,
  id_direccion INTEGER REFERENCES direccion(id_direccion) ON UPDATE CASCADE
);


CREATE TABLE linea_pedido (
  id_pedido INTEGER NOT NULL REFERENCES pedido (id_pedido) ON UPDATE CASCADE,
  id_ejemplar INTEGER NOT NULL REFERENCES ejemplar (isbn) ON UPDATE CASCADE,
  cantidad INTEGER NOT NULL CHECK(cantidad >= 0),
  precio NUMERIC(10,2) NOT NULL CHECK(precio >= 0.0),
  CONSTRAINT id_linea_pedido PRIMARY KEY(id_pedido, id_ejemplar)
);

CREATE TABLE linea_carrito (
  id_carrito INTEGER NOT NULL REFERENCES carrito (id_carrito) ON UPDATE CASCADE,
  id_ejemplar INTEGER NOT NULL REFERENCES ejemplar (isbn) ON UPDATE CASCADE,
  cantidad INTEGER NOT NULL CHECK(cantidad >= 0),
  CONSTRAINT id_linea_carrito PRIMARY KEY(id_carrito, id_ejemplar)
);

CREATE TABLE promocion_descuento (
  id_promocion_descuento SERIAL PRIMARY KEY,
  nombre_promocion VARCHAR(225),
  porcentaje NUMERIC(10,2) NOT NULL CHECK (porcentaje > 0 AND porcentaje < 100),
  fecha_inicio TIMESTAMP NOT NULL,
  fecha_fin TIMESTAMP NOT NULL,
  imagen text
);

CREATE TABLE ejemplar_promocion (
  id_ejemplar INTEGER NOT NULL REFERENCES ejemplar (isbn) ON UPDATE CASCADE,
  id_promocion_descuento INTEGER NOT NULL REFERENCES promocion_descuento (id_promocion_descuento) ON UPDATE CASCADE,
  CONSTRAINT id_libro_promocion PRIMARY KEY(id_ejemplar, id_promocion_descuento)
);

CREATE TABLE sesion(
  id_sesion text PRIMARY KEY,
  id_usuario text NOT NULL REFERENCES usuario(id_usuario) ON UPDATE CASCADE
);

CREATE TABLE reposicion (
  id_reposicion SERIAL PRIMARY KEY,
  fecha_reposicion TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
  id_ejemplar INTEGER NOT NULL REFERENCES ejemplar(isbn) ON UPDATE CASCADE,
  stock_incorporado INTEGER NOT NULL
);
CREATE TABLE pregunta_frecuente (
    id serial PRIMARY KEY,
    pregunta VARCHAR(255) NOT NULL,
    respuesta VARCHAR(500) NOT NULL
);

CREATE USER vendedor WITH PASSWORD '1111';
CREATE USER empleado WITH PASSWORD '2222';

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO vendedor;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO empleado;

COMMIT;