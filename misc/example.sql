--##PAGES
INSERT INTO `page` VALUES
/* namespace != 0, should not be kept */
(1,1,'dumbledore',0,0,0.0,'0','0',0,0,'',NULL),
/* namespace != 0, should not be kept */
(2,1,'albus dumbledore',1,0,0.0,'0','0',0,0,'',NULL),
(3,0,'gandalf',0,0,0.0,'0','0',0,0,'',NULL),
(4,0,'mithrandir',1,0,0.0,'0','0',0,0,'',NULL),
(5,0,'the grey wizard',1,0,0.0,'0','0',0,0,'',NULL),
(6,0,'sauron',0,0,0.0,'0','0',0,0,'',NULL),
(7,0,'the dark lord',1,0,0.0,'0','0',0,0,'',NULL),
(8,0,'the necromancer',1,0,0.0,'0','0',0,0,'',NULL),
(9,0,'celebrimbor',0,0,0.0,'0','0',0,0,'',NULL),
(10,0,'morgoth',0,0,0.0,'0','0',0,0,'',NULL),
(11,0,'wizard',0,0,0.0,'0','0',0,0,'',NULL),
(12,0,'good',0,0,0.0,'0','0',0,0,'',NULL),
(13,0,'evil',0,0,0.0,'0','0',0,0,'',NULL),
/* TODO: repeat title, should not be kept */
(14,0,'evil',0,0,0.0,'0','0',0,0,'',NULL),
(15,0,'wisdom',0,0,0.0,'0','0',0,0,'',NULL),
/* repeat id, should not be kept */
(15,0,'wisdom',0,0,0.0,'0','0',0,0,'',NULL),
/* redirect page with no redirects, should not be kept */
(16,0,'nothing',1,0,0.0,'0','0',0,0,'',NULL),
(17,0,'redirectA',1,0,0.0,'0','0',0,0,'',NULL),
(18,0,'redirectB',1,0,0.0,'0','0',0,0,'',NULL),
(19,0,'redirectC',1,0,0.0,'0','0',0,0,'',NULL),
/* categories */
(20,14,'wizards',0,0,0.0,'0','0',0,0,'',NULL),
(21,14,'gods',1,0,0.0,'0','0',0,0,'',NULL),
(22,14,'aspects',0,0,0.0,'0','0',0,0,'',NULL),
/* have hiddencat prop, should not be kept */
(23,14,'hidden_cat1',1,0,0.0,'0','0',0,0,'',NULL),
/* have hiddencat prop, should not be kept */
(24,14,'hidden_cat2',0,0,0.0,'0','0',0,0,'',NULL),
(25,0,'stormcrow',1,0,0.0,'0','0',0,0,'',NULL),
(26,0,'bombadil',0,0,0.0,'0','0',0,0,'',NULL),
(27,0,'the bright lord',1,0,0.0,'0','0',0,0,'',NULL),
(28,0,'test_node',0,0,0.0,'0','0',0,0,'',NULL),
(29,0,'test_redirect',1,0,0.0,'0','0',0,0,'',NULL);
--PAGES##

--##LINKS
INSERT INTO `pagelinks` VALUES
/* gandalf:1:wizard */
(3,0,1),
/* gandalf:2:wizard, repeat, should not be kept */
(3,0,2),
/* sauron:3:evil */
(6,0,3),
/* wizard:4:wisdom */
(11,0,4),
/* wizard:5:good */
(11,0,5),
/* celebrimbor:1:wizard, namespace != 0, should not be kept */
(9,1,1),
/* celebrimbor:10:toto, namespace != 0, should not be kept */
(9,0,10),
/* celebrimbor:NULL, should not be kept */
(9,0,NULL),
/* celebrimbor:6:NULL, should not be kept */
(9,0,6),
/* NULL:NULL, should not be kept */
(99,0,NULL),
/* NULL:7:celebrimbor, should not be kept */
(99,0,7),
/* gandalf:8:gandalf, self link, should not be kept */
(3,0,8),
/* redirectA:8:gandalf, link from a redirect page, should not be kept */
(17,0,8),
/* gandalf:9:redirectA, link to a redirect page */
(3,0,9),
/* evil:11:mithrandir */
(13,0,11),
/* morgoth:12:stormcrow */
(10,0,12),
/* morgoth:13:the dark lord */
(10,0,13),
/* morgoth:14:sauron */
(10,0,14),
/* bombadil:15:the grey wizard */
(26,0,15),
/* wisdom:16:the bright lord */
(15,0,16),
/* good:17:the bright lord */
(12,0,17),
/* wizard:18:test_redirect */
(11,0,18),
/* test_node:7:celebrimbor */
(28,0,7);
--LINKS##

--##LINKTARGETS
INSERT INTO `linktarget` VALUES
(1,0,'wizard'),
/* repeat, should not matter */
(2,0,'wizard'),
(3,0,'evil'),
(4,0,'wisdom'),
(5,0,'good'),
(6,0,NULL),
(NULL,0,11),
(NULL,0,NULL),
(7,0,'celebrimbor'),
(8,0,'gandalf'),
(9,0,'redirectA'),
/* namespace != 0, should not be kept */
(10,1,'toto'),
(11,0,'mithrandir'),
(12,0,'stormcrow'),
(13,0,'the dark lord'),
(14,0,'sauron'),
(15,0,'the grey wizard'),
(16,0,'the bright lord'),
(17,0,'the bright lord'),
(18,0,'test_redirect');
--LINKTARGETS##

--##REDIRECTS
INSERT INTO `redirect` VALUES
/* 2:1, namespace != 0, should not be kept */
(2,0,'dumbledore','',''),
/* 4:3 */
(4,0,'gandalf','',''),
/* 4:3, repeat, should not be kept */
(4,0,'gandalf','',''),
/* 5:3 */
(5,0,'gandalf','',''),
/* 7:6 */
(7,0,'sauron','',''),
/* 8:6, namespace != 0, should not be kept */
(8,1,'sauron','',''),
/* 9:NULL, should not be kept */
(9,0,'NULL','',''),
/* NULL:NULL, should not be kept */
(99,0,'NULL','',''),
/* NULL:9, should not be kept */
(99,0,'celebrimbor','',''),
/* 5:5, self redirect, should not be kept*/
(5,0,'the grey wizard','',''),
/* 13:12, not a redirect page, should not be kept */
(13,0,'good','','');
/* 17:18, redirect to a redirect */
(17,0,'redirectB','',''),
/* 18:19, redirect to a redirect */
(18,0,'redirectC','',''),
/* TODO: 19:18, circular redirect, should not be kept */
(19,0,'redirectB','',''),
/* 25:4, redirect to a redirect */
(25,0,'mithrandir','',''),
(27,0,'celebrimbor','',''),
(29,0,'test_node','','');
--REDIRECTS##

--##PAGEPROPS
INSERT INTO `page_props` VALUES
(20,'prop_name1','prop_value1',NULL),
(21,'prop_name1','prop_value1',NULL),
(22,'prop_name2','prop_value2',NULL),
(23,'hiddencat','',NULL),
(24,'hiddencat','',NULL),
--PAGEPROPS##

--##CATEGORIES
INSERT INTO `category` VALUES
(1,'wizards',NULL,NULL,NULL),
(2,'gods',NULL,NULL,NULL),
(3,'aspects',NULL,NULL,NULL);
--CATEGORIES##

--##CATEGORYLINKS
INSERT INTO `categorylinks` VALUES
(1,'wizards',NULL,NULL,NULL,NULL,NULL),
(2,'wizards',NULL,NULL,NULL,NULL,NULL),
(3,'wizards',NULL,NULL,NULL,NULL,NULL),
(4,'wizards',NULL,NULL,NULL,NULL,NULL),
(5,'wizards',NULL,NULL,NULL,NULL,NULL),
(6,'gods',NULL,NULL,NULL,NULL,NULL),
(7,'gods',NULL,NULL,NULL,NULL,NULL),
(8,'gods',NULL,NULL,NULL,NULL,NULL),
(10,'gods',NULL,NULL,NULL,NULL,NULL),
(12,'aspects',NULL,NULL,NULL,NULL,NULL),
(13,'aspects',NULL,NULL,NULL,NULL,NULL),
(16,'aspects',NULL,NULL,NULL,NULL,NULL);
--CATEGORYLINKS##