-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 18-11-2026 a las 22:50:40
-- Versión del servidor: 10.4.32-MariaDB
-- Versión de PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `larence`
--

DELIMITER $$
--
-- Procedimientos
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `aplicar_descuento_volumen` (IN `p_id_detalle` INT(11))   BEGIN


    UPDATE detalles_pedido 


    SET precio_unitario = precio_unitario * 0.90 


    WHERE id_detalle = p_id_detalle 


    AND cantidad > 50;


END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `calcular_total_con_iva` (IN `p_id_pedido` INT, OUT `p_total_final` DECIMAL(10,2))   BEGIN


    DECLARE v_subtotal DECIMAL(10,2);


    SELECT total INTO v_subtotal 


    FROM pedidos 


    WHERE id_pedido = p_id_pedido;


    SET p_total_final = v_subtotal * 1.16;


END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `generar_reporte_ventas_dia` (IN `p_fecha` DATE)   BEGIN


    SELECT p.nombre_producto, 


           SUM(dp.cantidad) as total_vendido, 


           SUM(dp.cantidad * dp.precio_unitario) as monto_total


    FROM productos p


    JOIN detalles_pedido dp ON p.id_producto = dp.id_producto


    JOIN pedidos ped ON dp.id_pedido = ped.id_pedido


    WHERE ped.fecha_pedido = p_fecha


    GROUP BY p.nombre_producto;


END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `registrar_pedido_seguro` (IN `p_id_cliente` INT, IN `p_id_producto` INT, IN `p_cantidad` INT, IN `p_precio` DECIMAL(10,2), OUT `p_mensaje` VARCHAR(100))   BEGIN


    DECLARE v_stock_actual INT;


    -- Manejador de errores (Si algo falla, hace ROLLBACK)


    DECLARE EXIT HANDLER FOR SQLEXCEPTION


    BEGIN


        ROLLBACK;


        SET p_mensaje = 'Error en la transacción. Cambios revertidos.';


    END;


    -- Iniciamos la transacción


    START TRANSACTION;


    -- Bloqueamos la fila del producto para evitar lecturas fantasmas


    SELECT stock INTO v_stock_actual FROM larence.productos WHERE id_producto = p_id_producto FOR UPDATE;


    IF v_stock_actual >= p_cantidad THEN


        -- Descontamos el inventario


        UPDATE larence.productos SET stock = stock - p_cantidad WHERE id_producto = p_id_producto;


        -- Confirmamos los cambios


        COMMIT;


        SET p_mensaje = 'Pedido registrado y stock descontado con éxito.';


    ELSE


        ROLLBACK;


        SET p_mensaje = 'Transacción rechazada: Stock insuficiente en almacén.';


    END IF;


END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_actualizar_tasa_cambio` (IN `p_moneda` VARCHAR(50), IN `p_monto` DECIMAL(10,2))   BEGIN

    INSERT INTO tasa_dia (moneda_tasa, monto_tasa, fecha_tasa, status)

    VALUES (p_moneda, p_monto, NOW(), 1);

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_anular_pedido` (IN `p_id_pedido` INT)   BEGIN

    DECLARE done INT DEFAULT FALSE;

    DECLARE v_id_producto INT;

    DECLARE v_cantidad INT;

    
    DECLARE cur CURSOR FOR 

        SELECT id_producto, cantidad FROM detalle_pedidos WHERE id_pedido = p_id_pedido;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;


    START TRANSACTION;


    -- Devolver stock de los productos del pedido

    OPEN cur;

    read_loop: LOOP

        FETCH cur INTO v_id_producto, v_cantidad;

        IF done THEN

            LEAVE read_loop;

        END IF;

        UPDATE productos SET stock = stock + v_cantidad WHERE id_producto = v_id_producto;

    END LOOP;

    CLOSE cur;


    -- Cambiar estatus del pedido

    UPDATE pedidos SET status = 0 WHERE id_pedido = p_id_pedido;


    COMMIT;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_registrar_pago_cliente` (IN `p_id_pedido` INT, IN `p_monto` DECIMAL(10,2), IN `p_nro_ref` VARCHAR(11), IN `p_metodo` INT, IN `p_concepto` VARCHAR(200), IN `p_img` VARCHAR(100))   BEGIN

    -- Insertar el pago

    INSERT INTO pagos (id_pedido, monto_pago, fecha_pago, nro_referencia, concepto, id_metodo_pago, img_pago)

    VALUES (p_id_pedido, p_monto, NOW(), p_nro_ref, p_concepto, p_metodo, p_img);


    -- Actualizar la cuenta por cobrar

    UPDATE cuenta_x_cobrar 

    SET saldo_pendiente = GREATEST(0, saldo_pendiente - p_monto),

        estado_cuenta = IF(saldo_pendiente - p_monto <= 0, 'Pagado', 'Por Pagar')

    WHERE id_pedido = p_id_pedido;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_registrar_produccion` (IN `p_id_producto` INT, IN `p_cantidad` INT, IN `p_fecha` DATE, IN `p_motivo` VARCHAR(100), IN `p_observacion` VARCHAR(100))   BEGIN

    START TRANSACTION;


    -- Insertar en la tabla producciones

    INSERT INTO producciones (id_producto, cantidad_producida, fecha_produccion, motivo_produccion, observacion, status)

    VALUES (p_id_producto, p_cantidad, p_fecha, p_motivo, p_observacion, 1);


    -- Aumentar el stock en productos

    UPDATE productos 

    SET stock = stock + p_cantidad 

    WHERE id_producto = p_id_producto;


    COMMIT;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `verificar_reposicion` (IN `p_total_final` DECIMAL(10,2))   BEGIN


    SELECT nombre_producto, stock 


    FROM productos 


    WHERE stock < 10;


END$$

--
-- Funciones
--
CREATE DEFINER=`root`@`localhost` FUNCTION `calcular_precio_bs` (`p_precio_dolares` DECIMAL(10,2)) RETURNS DECIMAL(10,2) READS SQL DATA BEGIN


    DECLARE v_tasa_actual DECIMAL(10,2);


    DECLARE v_precio_final DECIMAL(10,2);


    -- Buscar la tasa activa más reciente


    SELECT monto_tasa INTO v_tasa_actual FROM larence.tasa_dia WHERE status = 1 ORDER BY id_tasa DESC LIMIT 1;


    -- Calcular


    SET v_precio_final = p_precio_dolares * v_tasa_actual;


    RETURN v_precio_final;


END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_calcular_monto_dolares` (`p_monto_bs` DECIMAL(10,2)) RETURNS DECIMAL(10,2) READS SQL DATA BEGIN

    DECLARE v_tasa DECIMAL(10,2);

    DECLARE v_resultado DECIMAL(10,2);

    
    SELECT monto_tasa INTO v_tasa 

    FROM tasa_dia 

    WHERE status = 1 

    ORDER BY id_tasa DESC LIMIT 1;

    
    IF v_tasa IS NULL OR v_tasa = 0 THEN

        RETURN 0.00;

    END IF;

    
    SET v_resultado = p_monto_bs / v_tasa;

    RETURN v_resultado;

END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_descuento_promocion_activa` (`p_id_promocion` INT) RETURNS DECIMAL(10,2) READS SQL DATA BEGIN

    DECLARE v_descuento DECIMAL(10,2) DEFAULT 0.00;

    
    SELECT valor_descuento INTO v_descuento 

    FROM promociones 

    WHERE id_promocion = p_id_promocion AND estado = 1 AND status = 1;

    
    RETURN IFNULL(v_descuento, 0.00);

END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_dias_credito_cliente` (`p_id_cliente` INT) RETURNS INT(11) READS SQL DATA BEGIN

    DECLARE v_dias INT DEFAULT 0;

    
    SELECT tc.dias_credito INTO v_dias

    FROM clientes c

    JOIN tipos_clientes tc ON c.id_tipo_cliente = tc.id_tipo_cliente

    WHERE c.id_cliente = p_id_cliente;

    
    RETURN IFNULL(v_dias, 0);

END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_formato_identificacion` (`p_tipo` VARCHAR(11), `p_id` INT) RETURNS VARCHAR(50) CHARSET latin1 COLLATE latin1_swedish_ci DETERMINISTIC BEGIN

    RETURN CONCAT(UPPER(p_tipo), '-', p_id);

END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_obtener_stock_producto` (`p_id_producto` INT) RETURNS INT(11) READS SQL DATA BEGIN

    DECLARE v_stock INT DEFAULT 0;

    
    SELECT stock INTO v_stock 

    FROM productos 

    WHERE id_producto = p_id_producto;

    
    RETURN IFNULL(v_stock, 0);

END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_saldo_pendiente_cliente` (`p_id_cliente` INT) RETURNS DECIMAL(10,2) READS SQL DATA BEGIN

    DECLARE v_saldo DECIMAL(10,2) DEFAULT 0.00;

    
    SELECT SUM(saldo_pendiente) INTO v_saldo 

    FROM cuenta_x_cobrar 

    WHERE id_cliente = p_id_cliente AND estado_cuenta = 'Por Pagar' AND status = 1;

    
    RETURN IFNULL(v_saldo, 0.00);

END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_total_compras_mes` (`p_mes` INT, `p_anio` INT) RETURNS DECIMAL(10,2) READS SQL DATA BEGIN

    DECLARE v_total DECIMAL(10,2) DEFAULT 0.00;

    
    SELECT SUM(monto_total_compra) INTO v_total 

    FROM compras 

    WHERE MONTH(fecha_compra) = p_mes 

      AND YEAR(fecha_compra) = p_anio 

      AND status = 1;

      
    RETURN IFNULL(v_total, 0.00);

END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_total_producido_producto` (`p_id_producto` INT) RETURNS INT(11) READS SQL DATA BEGIN

    DECLARE v_total_producido INT DEFAULT 0;

    
    SELECT SUM(cantidad_producida) INTO v_total_producido 

    FROM producciones 

    WHERE id_producto = p_id_producto AND status = 1;

    
    RETURN IFNULL(v_total_producido, 0);

END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `camiones`
--

CREATE TABLE `camiones` (
  `id_camion` int(11) NOT NULL,
  `placa` varchar(10) NOT NULL,
  `modelo_marca` varchar(50) NOT NULL,
  `capacidad_peso_kg` decimal(10,2) NOT NULL DEFAULT 0.00,
  `capacidad_cajas` int(11) NOT NULL DEFAULT 0,
  `estado` enum('disponible','en_ruta','mantenimiento','inactivo') NOT NULL DEFAULT 'disponible',
  `status` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `carrito`
--

CREATE TABLE `carrito` (
  `id_carrito` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `id_cliente` int(11) DEFAULT NULL,
  `fecha_creacion` datetime NOT NULL DEFAULT current_timestamp(),
  `estado` enum('activo','convertido','cancelado') NOT NULL DEFAULT 'activo',
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `categorias`
--

CREATE TABLE `categorias` (
  `id_categoria` int(11) NOT NULL,
  `nombre_categoria` varchar(100) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `clientes`
--

CREATE TABLE `clientes` (
  `id_cliente` int(11) NOT NULL,
  `tipo_id` varchar(11) NOT NULL,
  `id_tipo_cliente` int(11) DEFAULT NULL,
  `nombre_cliente` varchar(100) NOT NULL,
  `direccion_cliente` varchar(100) NOT NULL,
  `sector` varchar(50) NOT NULL,
  `tlf_cliente` varchar(11) NOT NULL,
  `email_cliente` varchar(100) NOT NULL,
  `estado_cliente` varchar(100) NOT NULL,
  `fecha_registro` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `img_cliente` varchar(100) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `compras`
--

CREATE TABLE `compras` (
  `id_compra` int(11) NOT NULL,
  `id_proveedor` int(11) NOT NULL,
  `fecha_compra` datetime(6) NOT NULL,
  `monto_total_compra` float(11,2) NOT NULL,
  `id_tasa` int(11) NOT NULL,
  `id_estado_pago` int(11) NOT NULL,
  `observaciones` varchar(300) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `cuenta_x_cobrar`
--

CREATE TABLE `cuenta_x_cobrar` (
  `id_cuenta_x_cobrar` int(11) NOT NULL,
  `id_pedido` int(11) NOT NULL,
  `id_cliente` int(11) NOT NULL,
  `monto_total` float(11,2) NOT NULL,
  `saldo_pendiente` float(11,2) NOT NULL,
  `fecha_emision` date NOT NULL,
  `fecha_vencimiento` date NOT NULL,
  `estado_cuenta` varchar(100) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `cuenta_x_pagar`
--

CREATE TABLE `cuenta_x_pagar` (
  `id_cuenta_x_pagar` int(11) NOT NULL,
  `id_compra` int(11) NOT NULL,
  `id_proveedor` int(11) NOT NULL,
  `monto_total` float(11,2) NOT NULL,
  `saldo_pendiente` float(11,2) NOT NULL,
  `fecha_emision` datetime(6) NOT NULL,
  `fecha_vencimiento` datetime(6) NOT NULL,
  `estado_pago` varchar(100) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalles_entregas`
--

CREATE TABLE `detalles_entregas` (
  `id_detalle_entrega` int(11) NOT NULL,
  `id_entrega` int(11) NOT NULL,
  `id_pedido` int(11) NOT NULL,
  `id_cliente` int(11) NOT NULL,
  `tlt_contacto` varchar(11) NOT NULL,
  `direccion_entrega` varchar(100) NOT NULL,
  `cantidad_caja` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_carrito`
--

CREATE TABLE `detalle_carrito` (
  `id_detalle_carrito` int(11) NOT NULL,
  `id_carrito` int(11) NOT NULL,
  `id_producto` int(11) NOT NULL,
  `cantidad` int(11) NOT NULL,
  `precio_unitario` float(11,2) NOT NULL,
  `fecha_agregado` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_compras`
--

CREATE TABLE `detalle_compras` (
  `id_detalle_compra` int(11) NOT NULL,
  `id_compra` int(11) NOT NULL,
  `id_materia_prima` int(11) NOT NULL,
  `cantidad` int(11) NOT NULL,
  `precio_unitario` float(11,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_pedidos`
--

CREATE TABLE `detalle_pedidos` (
  `id_detalle_pedido` int(11) NOT NULL,
  `id_pedido` int(11) NOT NULL,
  `id_producto` int(11) NOT NULL,
  `cantidad` int(11) NOT NULL,
  `precio_unitario` float(11,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_producciones`
--

CREATE TABLE `detalle_producciones` (
  `id_detalle_produccion` int(11) NOT NULL,
  `id_produccion` int(11) NOT NULL,
  `id_materia_prima` int(11) NOT NULL,
  `cantidad_utilizada` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_promocion`
--

CREATE TABLE `detalle_promocion` (
  `id_detalle_promocion` int(11) NOT NULL,
  `id_promocion` int(11) NOT NULL,
  `id_producto` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `entregas`
--

CREATE TABLE `entregas` (
  `id_entregas` int(11) NOT NULL,
  `fecha_entrega_programada` date NOT NULL,
  `fecha_entrega_real` date DEFAULT NULL,
  `id_estado_entrega` int(11) NOT NULL,
  `repartidor` varchar(200) NOT NULL,
  `id_camion` int(11) DEFAULT NULL,
  `observaciones` varchar(300) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1,
  `id_pedido` int(11) NOT NULL,
  `id_estado` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `entrega_pedidos`
--

CREATE TABLE `entrega_pedidos` (
  `id_entrega_pedido` int(11) NOT NULL,
  `id_entrega` int(11) NOT NULL,
  `id_pedido` int(11) NOT NULL,
  `id_cliente` int(11) NOT NULL,
  `direccion_entrega` varchar(300) NOT NULL,
  `tlf_contacto` varchar(12) DEFAULT NULL,
  `cantidad_cajas` int(11) NOT NULL DEFAULT 0,
  `observaciones` varchar(300) DEFAULT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `estado_entrega`
--

CREATE TABLE `estado_entrega` (
  `id_estado_entrega` int(11) NOT NULL,
  `nombre_estado` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `estado_pago`
--

CREATE TABLE `estado_pago` (
  `id_estado_pago` int(11) NOT NULL,
  `nombre_estado` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `estado_pedido`
--

CREATE TABLE `estado_pedido` (
  `id_estado_pedido` int(11) NOT NULL,
  `nombre_estado` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `materia_prima`
--

CREATE TABLE `materia_prima` (
  `id_materia_prima` int(11) NOT NULL,
  `nombre_materia_prima` varchar(100) NOT NULL,
  `descripcion_materia_prima` varchar(100) NOT NULL,
  `id_unidad_medida` int(11) NOT NULL,
  `stock_actual` int(11) NOT NULL,
  `id_proveedor` int(11) NOT NULL,
  `fecha_registro` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `metodos_pago`
--

CREATE TABLE `metodos_pago` (
  `id_metodo_pago` int(11) NOT NULL,
  `nombre_metodo` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `monedas`
--

CREATE TABLE `monedas` (
  `id_moneda` int(11) NOT NULL,
  `nombre_moneda` varchar(50) NOT NULL,
  `descripcion_moneda` varchar(100) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pagos`
--

CREATE TABLE `pagos` (
  `id_pago` int(11) NOT NULL,
  `id_pedido` int(11) NOT NULL,
  `monto_pago` float(11,2) NOT NULL,
  `fecha_pago` datetime(6) NOT NULL,
  `nro_referencia` varchar(11) NOT NULL,
  `concepto` varchar(200) NOT NULL,
  `id_metodo_pago` int(11) NOT NULL,
  `img_pago` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pagos_proveedores`
--

CREATE TABLE `pagos_proveedores` (
  `id_pago_proveedor` int(11) NOT NULL,
  `id_cuenta_x_pagar` int(11) NOT NULL,
  `monto` float(11,2) NOT NULL,
  `fecha_pago` float NOT NULL,
  `id_metodo_pago` int(11) NOT NULL,
  `nro_referencia` text NOT NULL,
  `concepto` varchar(300) NOT NULL,
  `img_pago` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pedidos`
--

CREATE TABLE `pedidos` (
  `id_pedido` int(11) NOT NULL,
  `id_cliente` int(11) NOT NULL,
  `fecha_pedido` datetime(6) NOT NULL,
  `id_estado_pedido` int(11) NOT NULL,
  `id_estado_pago` int(11) NOT NULL,
  `monto_total_pedido` float(11,2) NOT NULL,
  `direccion_entrega` varchar(200) NOT NULL,
  `tlf_contacto` varchar(11) NOT NULL,
  `observaciones` varchar(250) NOT NULL,
  `id_promocion` int(11) DEFAULT NULL,
  `id_tasa` int(11) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `producciones`
--

CREATE TABLE `producciones` (
  `id_produccion` int(11) NOT NULL,
  `id_producto` int(11) NOT NULL,
  `cantidad_producida` int(11) NOT NULL,
  `fecha_produccion` date NOT NULL,
  `motivo_produccion` varchar(100) NOT NULL,
  `observacion` varchar(100) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `productos`
--

CREATE TABLE `productos` (
  `id_producto` int(11) NOT NULL,
  `nombre_producto` varchar(100) NOT NULL,
  `precio_venta` float(11,2) NOT NULL,
  `stock` int(11) NOT NULL,
  `fecha_registro` date NOT NULL,
  `fecha_vencimiento` date NOT NULL,
  `id_categoria` int(11) NOT NULL,
  `imagen` varchar(100) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1,
  `visibilidad_ecommerce` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `promociones`
--

CREATE TABLE `promociones` (
  `id_promocion` int(11) NOT NULL,
  `nombre_promocion` varchar(100) NOT NULL,
  `descripcion_promocion` varchar(100) NOT NULL,
  `fecha_inicio` date NOT NULL,
  `fecha_fin` date NOT NULL,
  `tipo_descuento` varchar(100) NOT NULL,
  `valor_descuento` float(11,2) NOT NULL,
  `estado` int(11) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `proveedores`
--

CREATE TABLE `proveedores` (
  `id_proveedor` int(11) NOT NULL,
  `tipo_id` varchar(11) NOT NULL,
  `nombre_proveedor` varchar(100) NOT NULL,
  `direccion_proveedor` varchar(100) NOT NULL,
  `tlf_proveedor` varchar(11) NOT NULL,
  `email_proveedor` varchar(100) NOT NULL,
  `fecha_registro` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tasa_dia`
--

CREATE TABLE `tasa_dia` (
  `id_tasa` int(11) NOT NULL,
  `id_moneda` int(11) NOT NULL,
  `monto_tasa` float(11,2) NOT NULL,
  `fecha_tasa` datetime(6) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tipos_clientes`
--

CREATE TABLE `tipos_clientes` (
  `id_tipo_cliente` int(11) NOT NULL,
  `nombre_tipo_cliente` varchar(100) NOT NULL,
  `dias_credito` int(11) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `unidad_medidas`
--

CREATE TABLE `unidad_medidas` (
  `id_unidad_medida` int(11) NOT NULL,
  `nombre_medida` varchar(100) NOT NULL,
  `descripcion_medida` varchar(100) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_clientes_vip`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_clientes_vip` (
`id_cliente` int(11)
,`gastado` double(19,2)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_compras_proveedores_totales`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_compras_proveedores_totales` (
`id_proveedor` int(11)
,`nombre_proveedor` varchar(100)
,`total_compras` bigint(21)
,`monto_total_invertido` double(19,2)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_cuentas_por_cobrar_pendientes`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_cuentas_por_cobrar_pendientes` (
`id_cuenta_x_cobrar` int(11)
,`nombre_cliente` varchar(100)
,`tlf_cliente` varchar(11)
,`id_pedido` int(11)
,`monto_total` float(11,2)
,`saldo_pendiente` float(11,2)
,`fecha_vencimiento` date
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_estado_despachos_entregas`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_estado_despachos_entregas` (
`id_entregas` int(11)
,`repartidor` varchar(200)
,`estado_despacho` varchar(100)
,`id_pedido` int(11)
,`nombre_cliente` varchar(100)
,`fecha_entrega_programada` date
,`fecha_entrega_real` date
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_materia_prima_critica`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_materia_prima_critica` (
`id_materia_prima` int(11)
,`nombre_materia_prima` varchar(100)
,`stock_actual` int(11)
,`nombre_medida` varchar(100)
,`nombre_proveedor` varchar(100)
,`tlf_proveedor` varchar(11)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_rendimiento_productos_top`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_rendimiento_productos_top` (
`id_producto` int(11)
,`nombre_producto` varchar(100)
,`nombre_categoria` varchar(100)
,`total_unidades_vendidas` decimal(32,0)
,`ingresos_generados` double(19,2)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_resumen_ventas_cliente`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_resumen_ventas_cliente` (
`id_cliente` int(11)
,`nombre_cliente` varchar(100)
,`total_pedidos` bigint(21)
,`total_comprado` double(19,2)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_seguimiento_produccion`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_seguimiento_produccion` (
`id_produccion` int(11)
,`nombre_producto` varchar(100)
,`cantidad_producida` int(11)
,`fecha_produccion` date
,`materia_prima_estimada_usada` decimal(12,1)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_stock_critico_natys`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_stock_critico_natys` (
`id_producto` int(11)
,`nombre_producto` varchar(100)
,`precio_venta` float(11,2)
,`stock` int(11)
,`nombre_categoria` varchar(100)
);

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_clientes_vip`
--
DROP TABLE IF EXISTS `vista_clientes_vip`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_clientes_vip`  AS SELECT `p`.`id_cliente` AS `id_cliente`, sum(`dp`.`cantidad` * `dp`.`precio_unitario`) AS `gastado` FROM (`pedidos` `p` join `detalle_pedidos` `dp` on(`p`.`id_pedido` = `dp`.`id_pedido`)) GROUP BY `p`.`id_cliente` HAVING `gastado` > 1000 ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_compras_proveedores_totales`
--
DROP TABLE IF EXISTS `vista_compras_proveedores_totales`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_compras_proveedores_totales`  AS SELECT `pr`.`id_proveedor` AS `id_proveedor`, `pr`.`nombre_proveedor` AS `nombre_proveedor`, count(`co`.`id_compra`) AS `total_compras`, coalesce(sum(`co`.`monto_total_compra`),0) AS `monto_total_invertido` FROM (`proveedores` `pr` left join `compras` `co` on(`pr`.`id_proveedor` = `co`.`id_proveedor` and `co`.`status` = 1)) GROUP BY `pr`.`id_proveedor`, `pr`.`nombre_proveedor` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_cuentas_por_cobrar_pendientes`
--
DROP TABLE IF EXISTS `vista_cuentas_por_cobrar_pendientes`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_cuentas_por_cobrar_pendientes`  AS SELECT `cxc`.`id_cuenta_x_cobrar` AS `id_cuenta_x_cobrar`, `c`.`nombre_cliente` AS `nombre_cliente`, `c`.`tlf_cliente` AS `tlf_cliente`, `cxc`.`id_pedido` AS `id_pedido`, `cxc`.`monto_total` AS `monto_total`, `cxc`.`saldo_pendiente` AS `saldo_pendiente`, `cxc`.`fecha_vencimiento` AS `fecha_vencimiento` FROM (`cuenta_x_cobrar` `cxc` join `clientes` `c` on(`cxc`.`id_cliente` = `c`.`id_cliente`)) WHERE `cxc`.`estado_cuenta` = 'Por Pagar' AND `cxc`.`status` = 1 ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_estado_despachos_entregas`
--
DROP TABLE IF EXISTS `vista_estado_despachos_entregas`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_estado_despachos_entregas`  AS SELECT `e`.`id_entregas` AS `id_entregas`, `e`.`repartidor` AS `repartidor`, `ee`.`nombre_estado` AS `estado_despacho`, `p`.`id_pedido` AS `id_pedido`, `c`.`nombre_cliente` AS `nombre_cliente`, `e`.`fecha_entrega_programada` AS `fecha_entrega_programada`, `e`.`fecha_entrega_real` AS `fecha_entrega_real` FROM (((`entregas` `e` join `estado_entrega` `ee` on(`e`.`id_estado_entrega` = `ee`.`id_estado_entrega`)) join `pedidos` `p` on(`e`.`id_pedido` = `p`.`id_pedido`)) join `clientes` `c` on(`p`.`id_cliente` = `c`.`id_cliente`)) WHERE `e`.`status` = 1 ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_materia_prima_critica`
--
DROP TABLE IF EXISTS `vista_materia_prima_critica`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_materia_prima_critica`  AS SELECT `mp`.`id_materia_prima` AS `id_materia_prima`, `mp`.`nombre_materia_prima` AS `nombre_materia_prima`, `mp`.`stock_actual` AS `stock_actual`, `um`.`nombre_medida` AS `nombre_medida`, `pr`.`nombre_proveedor` AS `nombre_proveedor`, `pr`.`tlf_proveedor` AS `tlf_proveedor` FROM ((`materia_prima` `mp` join `unidad_medidas` `um` on(`mp`.`id_unidad_medida` = `um`.`id_unidad_medida`)) join `proveedores` `pr` on(`mp`.`id_proveedor` = `pr`.`id_proveedor`)) WHERE `mp`.`stock_actual` < 30 AND `mp`.`status` = 1 ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_rendimiento_productos_top`
--
DROP TABLE IF EXISTS `vista_rendimiento_productos_top`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_rendimiento_productos_top`  AS SELECT `pr`.`id_producto` AS `id_producto`, `pr`.`nombre_producto` AS `nombre_producto`, `cat`.`nombre_categoria` AS `nombre_categoria`, coalesce(sum(`dp`.`cantidad`),0) AS `total_unidades_vendidas`, coalesce(sum(`dp`.`cantidad` * `dp`.`precio_unitario`),0) AS `ingresos_generados` FROM ((`productos` `pr` join `categorias` `cat` on(`pr`.`id_categoria` = `cat`.`id_categoria`)) left join `detalle_pedidos` `dp` on(`pr`.`id_producto` = `dp`.`id_producto`)) GROUP BY `pr`.`id_producto`, `pr`.`nombre_producto`, `cat`.`nombre_categoria` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_resumen_ventas_cliente`
--
DROP TABLE IF EXISTS `vista_resumen_ventas_cliente`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_resumen_ventas_cliente`  AS SELECT `c`.`id_cliente` AS `id_cliente`, `c`.`nombre_cliente` AS `nombre_cliente`, count(`p`.`id_pedido`) AS `total_pedidos`, coalesce(sum(`p`.`monto_total_pedido`),0) AS `total_comprado` FROM (`clientes` `c` left join `pedidos` `p` on(`c`.`id_cliente` = `p`.`id_cliente` and `p`.`status` = 1)) GROUP BY `c`.`id_cliente`, `c`.`nombre_cliente` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_seguimiento_produccion`
--
DROP TABLE IF EXISTS `vista_seguimiento_produccion`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_seguimiento_produccion`  AS SELECT `prod`.`id_produccion` AS `id_produccion`, `p`.`nombre_producto` AS `nombre_producto`, `prod`.`cantidad_producida` AS `cantidad_producida`, `prod`.`fecha_produccion` AS `fecha_produccion`, `prod`.`cantidad_producida`* 0.5 AS `materia_prima_estimada_usada` FROM (`producciones` `prod` join `productos` `p` on(`prod`.`id_producto` = `p`.`id_producto`)) ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_stock_critico_natys`
--
DROP TABLE IF EXISTS `vista_stock_critico_natys`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_stock_critico_natys`  AS SELECT `p`.`id_producto` AS `id_producto`, `p`.`nombre_producto` AS `nombre_producto`, `p`.`precio_venta` AS `precio_venta`, `p`.`stock` AS `stock`, `c`.`nombre_categoria` AS `nombre_categoria` FROM (`productos` `p` join `categorias` `c` on(`p`.`id_categoria` = `c`.`id_categoria`)) WHERE `p`.`stock` < 50 ;

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `camiones`
--
ALTER TABLE `camiones`
  ADD PRIMARY KEY (`id_camion`),
  ADD UNIQUE KEY `uq_placa` (`placa`);

--
-- Indices de la tabla `carrito`
--
ALTER TABLE `carrito`
  ADD PRIMARY KEY (`id_carrito`),
  ADD KEY `idx_carrito_usuario_estado` (`id_usuario`,`estado`);

--
-- Indices de la tabla `categorias`
--
ALTER TABLE `categorias`
  ADD PRIMARY KEY (`id_categoria`);

--
-- Indices de la tabla `clientes`
--
ALTER TABLE `clientes`
  ADD PRIMARY KEY (`id_cliente`),
  ADD KEY `id_tipo_cliente` (`id_tipo_cliente`);

--
-- Indices de la tabla `compras`
--
ALTER TABLE `compras`
  ADD PRIMARY KEY (`id_compra`),
  ADD KEY `id_proveedor` (`id_proveedor`),
  ADD KEY `id_tasa` (`id_tasa`),
  ADD KEY `id_estado_pago` (`id_estado_pago`),
  ADD KEY `idx_compras_proveedor_fecha` (`id_proveedor`,`fecha_compra`);

--
-- Indices de la tabla `cuenta_x_cobrar`
--
ALTER TABLE `cuenta_x_cobrar`
  ADD PRIMARY KEY (`id_cuenta_x_cobrar`),
  ADD KEY `id_pedido` (`id_pedido`),
  ADD KEY `id_cliente` (`id_cliente`),
  ADD KEY `idx_cuentas_estado_vencimiento` (`estado_cuenta`,`fecha_vencimiento`);

--
-- Indices de la tabla `cuenta_x_pagar`
--
ALTER TABLE `cuenta_x_pagar`
  ADD PRIMARY KEY (`id_cuenta_x_pagar`),
  ADD KEY `id_compra` (`id_compra`),
  ADD KEY `id_proveedor` (`id_proveedor`);

--
-- Indices de la tabla `detalles_entregas`
--
ALTER TABLE `detalles_entregas`
  ADD PRIMARY KEY (`id_detalle_entrega`),
  ADD KEY `id_entrega` (`id_entrega`),
  ADD KEY `id_pedido` (`id_pedido`),
  ADD KEY `id_cliente` (`id_cliente`);

--
-- Indices de la tabla `detalle_carrito`
--
ALTER TABLE `detalle_carrito`
  ADD PRIMARY KEY (`id_detalle_carrito`),
  ADD KEY `id_carrito` (`id_carrito`),
  ADD KEY `id_producto` (`id_producto`);

--
-- Indices de la tabla `detalle_compras`
--
ALTER TABLE `detalle_compras`
  ADD PRIMARY KEY (`id_detalle_compra`),
  ADD KEY `id_compra` (`id_compra`),
  ADD KEY `id_materia_prima` (`id_materia_prima`);

--
-- Indices de la tabla `detalle_pedidos`
--
ALTER TABLE `detalle_pedidos`
  ADD PRIMARY KEY (`id_detalle_pedido`),
  ADD KEY `id_pedido` (`id_pedido`),
  ADD KEY `id_producto` (`id_producto`),
  ADD KEY `idx_detalle_pedidos_producto` (`id_producto`);

--
-- Indices de la tabla `detalle_producciones`
--
ALTER TABLE `detalle_producciones`
  ADD PRIMARY KEY (`id_detalle_produccion`),
  ADD KEY `id_produccion` (`id_produccion`),
  ADD KEY `id_materia_prima` (`id_materia_prima`);

--
-- Indices de la tabla `detalle_promocion`
--
ALTER TABLE `detalle_promocion`
  ADD PRIMARY KEY (`id_detalle_promocion`),
  ADD KEY `id_promocion` (`id_promocion`),
  ADD KEY `id_producto` (`id_producto`);

--
-- Indices de la tabla `entregas`
--
ALTER TABLE `entregas`
  ADD PRIMARY KEY (`id_entregas`),
  ADD KEY `id_estado_entrega` (`id_estado_entrega`),
  ADD KEY `fecha_entrega_programada` (`fecha_entrega_programada`),
  ADD KEY `idx_entregas_estado_pedido` (`id_estado_entrega`,`id_pedido`),
  ADD KEY `id_camion` (`id_camion`);

--
-- Indices de la tabla `entrega_pedidos`
--
ALTER TABLE `entrega_pedidos`
  ADD PRIMARY KEY (`id_entrega_pedido`),
  ADD KEY `idx_ep_entrega` (`id_entrega`),
  ADD KEY `idx_ep_pedido` (`id_pedido`);

--
-- Indices de la tabla `estado_entrega`
--
ALTER TABLE `estado_entrega`
  ADD PRIMARY KEY (`id_estado_entrega`);

--
-- Indices de la tabla `estado_pago`
--
ALTER TABLE `estado_pago`
  ADD PRIMARY KEY (`id_estado_pago`);

--
-- Indices de la tabla `estado_pedido`
--
ALTER TABLE `estado_pedido`
  ADD PRIMARY KEY (`id_estado_pedido`);

--
-- Indices de la tabla `materia_prima`
--
ALTER TABLE `materia_prima`
  ADD PRIMARY KEY (`id_materia_prima`),
  ADD KEY `id_unidad_medida` (`id_unidad_medida`),
  ADD KEY `id_proveedor` (`id_proveedor`),
  ADD KEY `idx_materia_prima_stock` (`stock_actual`);

--
-- Indices de la tabla `metodos_pago`
--
ALTER TABLE `metodos_pago`
  ADD PRIMARY KEY (`id_metodo_pago`);

--
-- Indices de la tabla `monedas`
--
ALTER TABLE `monedas`
  ADD PRIMARY KEY (`id_moneda`);

--
-- Indices de la tabla `pagos`
--
ALTER TABLE `pagos`
  ADD PRIMARY KEY (`id_pago`),
  ADD KEY `id_pedido` (`id_pedido`),
  ADD KEY `id_metodo_pago` (`id_metodo_pago`),
  ADD KEY `idx_pagos_pedido_fecha` (`id_pedido`,`fecha_pago`);

--
-- Indices de la tabla `pagos_proveedores`
--
ALTER TABLE `pagos_proveedores`
  ADD PRIMARY KEY (`id_pago_proveedor`),
  ADD KEY `id_cuenta_x_pagar` (`id_cuenta_x_pagar`),
  ADD KEY `id_metodo_pago` (`id_metodo_pago`);

--
-- Indices de la tabla `pedidos`
--
ALTER TABLE `pedidos`
  ADD PRIMARY KEY (`id_pedido`),
  ADD KEY `id_cliente` (`id_cliente`),
  ADD KEY `id_estado_pedido` (`id_estado_pedido`),
  ADD KEY `id_estado_pago` (`id_estado_pago`),
  ADD KEY `id_tasa` (`id_tasa`),
  ADD KEY `id_promocion` (`id_promocion`),
  ADD KEY `fecha_pedido` (`fecha_pedido`),
  ADD KEY `idx_pedidos_cliente_fecha` (`id_cliente`,`fecha_pedido`);

--
-- Indices de la tabla `producciones`
--
ALTER TABLE `producciones`
  ADD PRIMARY KEY (`id_produccion`),
  ADD KEY `id_producto` (`id_producto`),
  ADD KEY `idx_producciones_producto_fecha` (`id_producto`,`fecha_produccion`);

--
-- Indices de la tabla `productos`
--
ALTER TABLE `productos`
  ADD PRIMARY KEY (`id_producto`),
  ADD KEY `id_categoria` (`id_categoria`),
  ADD KEY `idx_productos_categoria_status` (`id_categoria`,`status`);

--
-- Indices de la tabla `promociones`
--
ALTER TABLE `promociones`
  ADD PRIMARY KEY (`id_promocion`);

--
-- Indices de la tabla `proveedores`
--
ALTER TABLE `proveedores`
  ADD PRIMARY KEY (`id_proveedor`);

--
-- Indices de la tabla `tasa_dia`
--
ALTER TABLE `tasa_dia`
  ADD PRIMARY KEY (`id_tasa`),
  ADD KEY `id_moneda` (`id_moneda`);

--
-- Indices de la tabla `tipos_clientes`
--
ALTER TABLE `tipos_clientes`
  ADD PRIMARY KEY (`id_tipo_cliente`);

--
-- Indices de la tabla `unidad_medidas`
--
ALTER TABLE `unidad_medidas`
  ADD PRIMARY KEY (`id_unidad_medida`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `camiones`
--
ALTER TABLE `camiones`
  MODIFY `id_camion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT de la tabla `carrito`
--
ALTER TABLE `carrito`
  MODIFY `id_carrito` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `categorias`
--
ALTER TABLE `categorias`
  MODIFY `id_categoria` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=54;

--
-- AUTO_INCREMENT de la tabla `clientes`
--
ALTER TABLE `clientes`
  MODIFY `id_cliente` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2147483648;

--
-- AUTO_INCREMENT de la tabla `compras`
--
ALTER TABLE `compras`
  MODIFY `id_compra` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=34;

--
-- AUTO_INCREMENT de la tabla `cuenta_x_cobrar`
--
ALTER TABLE `cuenta_x_cobrar`
  MODIFY `id_cuenta_x_cobrar` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=163;

--
-- AUTO_INCREMENT de la tabla `cuenta_x_pagar`
--
ALTER TABLE `cuenta_x_pagar`
  MODIFY `id_cuenta_x_pagar` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=34;

--
-- AUTO_INCREMENT de la tabla `detalles_entregas`
--
ALTER TABLE `detalles_entregas`
  MODIFY `id_detalle_entrega` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=501;

--
-- AUTO_INCREMENT de la tabla `detalle_carrito`
--
ALTER TABLE `detalle_carrito`
  MODIFY `id_detalle_carrito` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT de la tabla `detalle_compras`
--
ALTER TABLE `detalle_compras`
  MODIFY `id_detalle_compra` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=185;

--
-- AUTO_INCREMENT de la tabla `detalle_pedidos`
--
ALTER TABLE `detalle_pedidos`
  MODIFY `id_detalle_pedido` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=794;

--
-- AUTO_INCREMENT de la tabla `detalle_producciones`
--
ALTER TABLE `detalle_producciones`
  MODIFY `id_detalle_produccion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=705;

--
-- AUTO_INCREMENT de la tabla `detalle_promocion`
--
ALTER TABLE `detalle_promocion`
  MODIFY `id_detalle_promocion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=85;

--
-- AUTO_INCREMENT de la tabla `entregas`
--
ALTER TABLE `entregas`
  MODIFY `id_entregas` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=159;

--
-- AUTO_INCREMENT de la tabla `entrega_pedidos`
--
ALTER TABLE `entrega_pedidos`
  MODIFY `id_entrega_pedido` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=492;

--
-- AUTO_INCREMENT de la tabla `estado_entrega`
--
ALTER TABLE `estado_entrega`
  MODIFY `id_estado_entrega` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `estado_pago`
--
ALTER TABLE `estado_pago`
  MODIFY `id_estado_pago` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT de la tabla `estado_pedido`
--
ALTER TABLE `estado_pedido`
  MODIFY `id_estado_pedido` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de la tabla `materia_prima`
--
ALTER TABLE `materia_prima`
  MODIFY `id_materia_prima` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT de la tabla `metodos_pago`
--
ALTER TABLE `metodos_pago`
  MODIFY `id_metodo_pago` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `monedas`
--
ALTER TABLE `monedas`
  MODIFY `id_moneda` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- AUTO_INCREMENT de la tabla `pagos`
--
ALTER TABLE `pagos`
  MODIFY `id_pago` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=481;

--
-- AUTO_INCREMENT de la tabla `pagos_proveedores`
--
ALTER TABLE `pagos_proveedores`
  MODIFY `id_pago_proveedor` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=99;

--
-- AUTO_INCREMENT de la tabla `pedidos`
--
ALTER TABLE `pedidos`
  MODIFY `id_pedido` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=163;

--
-- AUTO_INCREMENT de la tabla `producciones`
--
ALTER TABLE `producciones`
  MODIFY `id_produccion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=55;

--
-- AUTO_INCREMENT de la tabla `productos`
--
ALTER TABLE `productos`
  MODIFY `id_producto` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT de la tabla `promociones`
--
ALTER TABLE `promociones`
  MODIFY `id_promocion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `proveedores`
--
ALTER TABLE `proveedores`
  MODIFY `id_proveedor` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=987234924;

--
-- AUTO_INCREMENT de la tabla `tasa_dia`
--
ALTER TABLE `tasa_dia`
  MODIFY `id_tasa` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=24;

--
-- AUTO_INCREMENT de la tabla `tipos_clientes`
--
ALTER TABLE `tipos_clientes`
  MODIFY `id_tipo_cliente` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=36;

--
-- AUTO_INCREMENT de la tabla `unidad_medidas`
--
ALTER TABLE `unidad_medidas`
  MODIFY `id_unidad_medida` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=24;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `clientes`
--
ALTER TABLE `clientes`
  ADD CONSTRAINT `clientes_ibfk_1` FOREIGN KEY (`id_tipo_cliente`) REFERENCES `tipos_clientes` (`id_tipo_cliente`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `compras`
--
ALTER TABLE `compras`
  ADD CONSTRAINT `compras_ibfk_1` FOREIGN KEY (`id_proveedor`) REFERENCES `proveedores` (`id_proveedor`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `cuenta_x_cobrar`
--
ALTER TABLE `cuenta_x_cobrar`
  ADD CONSTRAINT `cuenta_x_cobrar_ibfk_2` FOREIGN KEY (`id_cliente`) REFERENCES `clientes` (`id_cliente`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `cuenta_x_pagar`
--
ALTER TABLE `cuenta_x_pagar`
  ADD CONSTRAINT `cuenta_x_pagar_ibfk_1` FOREIGN KEY (`id_compra`) REFERENCES `compras` (`id_compra`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `detalles_entregas`
--
ALTER TABLE `detalles_entregas`
  ADD CONSTRAINT `detalles_entregas_ibfk_1` FOREIGN KEY (`id_entrega`) REFERENCES `entregas` (`id_entregas`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `detalles_entregas_ibfk_2` FOREIGN KEY (`id_pedido`) REFERENCES `pedidos` (`id_pedido`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `detalle_carrito`
--
ALTER TABLE `detalle_carrito`
  ADD CONSTRAINT `detalle_carrito_ibfk_1` FOREIGN KEY (`id_carrito`) REFERENCES `carrito` (`id_carrito`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `detalle_carrito_ibfk_2` FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id_producto`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `detalle_compras`
--
ALTER TABLE `detalle_compras`
  ADD CONSTRAINT `detalle_compras_ibfk_1` FOREIGN KEY (`id_compra`) REFERENCES `compras` (`id_compra`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `detalle_compras_ibfk_2` FOREIGN KEY (`id_materia_prima`) REFERENCES `materia_prima` (`id_materia_prima`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `detalle_pedidos`
--
ALTER TABLE `detalle_pedidos`
  ADD CONSTRAINT `detalle_pedidos_ibfk_1` FOREIGN KEY (`id_pedido`) REFERENCES `pedidos` (`id_pedido`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `detalle_pedidos_ibfk_2` FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id_producto`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `detalle_producciones`
--
ALTER TABLE `detalle_producciones`
  ADD CONSTRAINT `detalle_producciones_ibfk_1` FOREIGN KEY (`id_produccion`) REFERENCES `producciones` (`id_produccion`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `detalle_producciones_ibfk_2` FOREIGN KEY (`id_materia_prima`) REFERENCES `materia_prima` (`id_materia_prima`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `detalle_promocion`
--
ALTER TABLE `detalle_promocion`
  ADD CONSTRAINT `detalle_promocion_ibfk_1` FOREIGN KEY (`id_promocion`) REFERENCES `promociones` (`id_promocion`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `detalle_promocion_ibfk_2` FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id_producto`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `entregas`
--
ALTER TABLE `entregas`
  ADD CONSTRAINT `entregas_ibfk_1` FOREIGN KEY (`id_estado_entrega`) REFERENCES `estado_entrega` (`id_estado_entrega`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `entregas_ibfk_2` FOREIGN KEY (`id_camion`) REFERENCES `camiones` (`id_camion`);

--
-- Filtros para la tabla `materia_prima`
--
ALTER TABLE `materia_prima`
  ADD CONSTRAINT `materia_prima_ibfk_1` FOREIGN KEY (`id_unidad_medida`) REFERENCES `unidad_medidas` (`id_unidad_medida`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `pagos`
--
ALTER TABLE `pagos`
  ADD CONSTRAINT `pagos_ibfk_1` FOREIGN KEY (`id_pedido`) REFERENCES `pedidos` (`id_pedido`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `pagos_ibfk_2` FOREIGN KEY (`id_metodo_pago`) REFERENCES `metodos_pago` (`id_metodo_pago`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `pagos_proveedores`
--
ALTER TABLE `pagos_proveedores`
  ADD CONSTRAINT `pagos_proveedores_ibfk_1` FOREIGN KEY (`id_cuenta_x_pagar`) REFERENCES `cuenta_x_pagar` (`id_cuenta_x_pagar`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `pedidos`
--
ALTER TABLE `pedidos`
  ADD CONSTRAINT `pedidos_ibfk_1` FOREIGN KEY (`id_cliente`) REFERENCES `clientes` (`id_cliente`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `pedidos_ibfk_2` FOREIGN KEY (`id_estado_pedido`) REFERENCES `estado_pedido` (`id_estado_pedido`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `pedidos_ibfk_3` FOREIGN KEY (`id_estado_pago`) REFERENCES `estado_pago` (`id_estado_pago`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `pedidos_ibfk_4` FOREIGN KEY (`id_tasa`) REFERENCES `tasa_dia` (`id_tasa`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `producciones`
--
ALTER TABLE `producciones`
  ADD CONSTRAINT `producciones_ibfk_1` FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id_producto`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `productos`
--
ALTER TABLE `productos`
  ADD CONSTRAINT `productos_ibfk_1` FOREIGN KEY (`id_categoria`) REFERENCES `categorias` (`id_categoria`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `tasa_dia`
--
ALTER TABLE `tasa_dia`
  ADD CONSTRAINT `tasa_dia_ibfk_1` FOREIGN KEY (`id_moneda`) REFERENCES `monedas` (`id_moneda`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
