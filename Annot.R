library("DOSE",verbose=FALSE,quietly=TRUE) #the EnrichR function
library("xlsx",verbose=FALSE,quietly=TRUE) #output xlsx
library("org.Mm.eg.db",verbose=FALSE,quietly=TRUE) #The main database all identifier with every one
library("STRINGdb",verbose=FALSE,quietly=TRUE) #String Database
library("clusterProfiler",verbose=FALSE,quietly=TRUE) #test the enrich list

TAXONOMY_NUMBER<-10090

########################################################################
#	ABSTRACT:
#		-To be called by other scripts
#		-Annotate the given list of genes using official_gene_symbol/the name of the gene in NCBI website Case Sensitive
#		-Output several files
#			-each .tsv per tested database
#			-each .tsv per tested database
#		-plot the data founded in STRINGdb
#		-Available databases:
#			Gene Ontology
#			KEGG pathway
#			Panther database
#			reactome database
#
#	INPUTS
#		-@GeneList list of gene Symbol (R vector)
#		-@Dir path to the directory of the ressources (R scalar/string)
#			default value "./RessourceDir"
#
#	PRODUCE
#		If data are not present out of R session, it will create the repertory and each pair of ressource file per tested database
#	
#	RETURN
#		Nothing for most of function
#
#
#	DESCRIPTION
#	Annotation script function
#		will use the data available in 
#			-org.HS.eg.db the databases with differents mappings ID for homo sapiens
#				-contains some genes with categories of interest
#				-contains id accross several database Official gene symbol/ENTREZ_ID/UNIPROT
#			-KEGG.db to get the names of the pathways
#			-Panther to get
#				-the mapping Entrez id/ pathway id
#				-the mapping Pathway name/ pathway id
#			-reactome to get
#				-the mapping Entrez id/ reactome id
#				-the mapping Pathway name/ pathway id
#		to build reference tables and will use clusterProfiler::enricher to do the statistics
#
#	Will compute the "Ressources" to avoid reloading them each time
#		-will create the Ressources directory
#		-will create all the necessary files per data base
#			- *.GeneList.txt (feature ID 1-N gene name)|tsv|with header file 
#			- *..Names.txt (feature ID 1-1 feature name)|tsv|with header file
#	
#

Dir<-"./Ressources/Annotations/"
BUILD<-FALSE
if(!dir.exists(Dir)){
	dir.create(Dir,recursive = TRUE)
	#library("KEGGREST")
}

if(!file.exists("ENdb_enhancer.txt")){
  download.file(
    url="https://bio.liclab.net/ENdb/file/download/ENdb_enhancer.txt",
    destfile = "ENdb_enhancer.txt")
}
Endb<-read.table("ENdb_enhancer.txt",sep="\t",comment.char = "@",quote = "\"",header = TRUE)



if(!file.exists("BIOGRID-ALL-4.4.231.tab3.txt")) {
  download.file(url = "https://downloads.thebiogrid.org/Download/BioGRID/Release-Archive/BIOGRID-4.4.231/BIOGRID-ALL-4.4.231.tab3.zip",
                destfile = "BIOGRID-ALL-4.4.231.tab3.zip")
  unzip(zipfile = "BIOGRID-ALL-4.4.231.tab3.zip")
}


BioGrid<-read.table("BIOGRID-ALL-4.4.231.tab3.txt",
                    header=TRUE,
                    sep="\t",
                    quote="\"",
                    comment.char ="$")
BioGrid<-BioGrid[
  BioGrid$Organism.ID.Interactor.A==TAXONOMY_NUMBER,]
BioGrid<-BioGrid[
  BioGrid$Organism.ID.Interactor.B==TAXONOMY_NUMBER,]
dim(BioGrid)

BioGrid$Gene_Symbol.A<-mapIds(org.Mm.eg.db,keys=as.character(BioGrid$Entrez.Gene.Interactor.A),
                             column="SYMBOL",keytype="ENTREZID",multiVals="first")
BioGrid$Gene_Symbol.B<-mapIds(org.Mm.eg.db,keys=as.character(BioGrid$Entrez.Gene.Interactor.B),
                              column="SYMBOL",keytype="ENTREZID",multiVals="first")
BioGrid<-BioGrid[,c("Gene_Symbol.A","Gene_Symbol.B")]
BioGrid<-rbind(BioGrid,BioGrid[,c("Gene_Symbol.B","Gene_Symbol.A")])
BioGrid<-BioGrid[order(BioGrid$Gene_Symbol.B),]
BioGrid2Gene<-BioGrid
BioGrid2Terms<-unique(BioGrid$Gene_Symbol.A)
BioGrid2Terms<-BioGrid2Terms[!is.na(BioGrid2Terms)]
BG2Terms<-data.frame(
  Interactor=BioGrid2Terms,
  Term=unlist(mapIds(org.Mm.eg.db,keys=as.character(BioGrid2Terms),
         column="GENENAME",keytype="SYMBOL",multiVals="first")))

if(file.exists(paste(Dir,"GO.BP.GeneList.txt",sep="")) & file.exists(paste(Dir,"GO.BP.Names.txt",sep="")) &
file.exists(paste(Dir,"GO.MF.GeneList.txt",sep="")) & file.exists(paste(Dir,"GO.MF.Names.txt",sep="")) &
file.exists(paste(Dir,"GO.CC.GeneList.txt",sep="")) & file.exists(paste(Dir,"GO.CC.Names.txt",sep=""))){
	BP2Genes<-read.table(paste(Dir,"GO.BP.GeneList.txt",sep=""),header=TRUE,sep="\t")
	CC2Genes<-read.table(paste(Dir,"GO.CC.GeneList.txt",sep=""),header=TRUE,sep="\t")
	MF2Genes<-read.table(paste(Dir,"GO.MF.GeneList.txt",sep=""),header=TRUE,sep="\t")
	GoTerms.BP<-read.table(paste(Dir,"GO.BP.Names.txt",sep=""),header=TRUE,sep="\t",quote="\"")
	GoTerms.CC<-read.table(paste(Dir,"GO.CC.Names.txt",sep=""),header=TRUE,sep="\t",quote="\"")
	GoTerms.MF<-read.table(paste(Dir,"GO.MF.Names.txt",sep=""),header=TRUE,sep="\t",quote="\"")
	

}else{
	#Gene Ontology part
	GoTerms<-toTable(GO.db::GOTERM)
	Genes2GO<-toTable(org.Mm.egGO2ALLEGS)
	Genes2GO$Gene_Symbol<-mapIds(org.Mm.eg.db,keys=as.character(Genes2GO$gene_id),
		column="SYMBOL",keytype="ENTREZID",multiVals="first")
	
	#Biological Process
	GoTerms.BP<-GoTerms[GoTerms$Ontology=="BP",]
	GoTerms.BP<-unique(GoTerms.BP[,c("go_id","Term")])
	BP2Genes<-Genes2GO[Genes2GO$Ontology=="BP",c("go_id","Gene_Symbol")]
	write.table(BP2Genes,paste(Dir,"GO.BP.GeneList.txt",sep=""),sep="\t",quote=FALSE,row.names=FALSE)
	write.table(GoTerms.BP,paste(Dir,"GO.BP.Names.txt",sep=""),sep="\t",quote=FALSE,row.names=FALSE)

	#Molecular Function
	GoTerms.MF<-GoTerms[GoTerms$Ontology=="MF",]
	GoTerms.MF<-unique(GoTerms.MF[,c("go_id","Term")])
	MF2Genes<-Genes2GO[Genes2GO$Ontology=="MF",c("go_id","Gene_Symbol")]
	write.table(MF2Genes,paste(Dir,"GO.MF.GeneList.txt",sep=""),sep="\t",quote=FALSE,row.names=FALSE)
	write.table(GoTerms.MF,paste(Dir,"GO.MF.Names.txt",sep=""),sep="\t",quote=FALSE,row.names=FALSE)

	#Cellular Component
	GoTerms.CC<-GoTerms[GoTerms$Ontology=="CC",]
	GoTerms.CC<-unique(GoTerms.CC[,c("go_id","Term")])
	CC2Genes<-Genes2GO[Genes2GO$Ontology=="CC",c("go_id","Gene_Symbol")]
	write.table(CC2Genes,paste(Dir,"GO.CC.GeneList.txt",sep=""),sep="\t",quote=FALSE,row.names=FALSE)
	write.table(GoTerms.CC,paste(Dir,"GO.CC.Names.txt",sep=""),sep="\t",quote=FALSE,row.names=FALSE)

}

#Reactome Part
if(file.exists(paste(Dir,"Reactome.DB.GeneList.txt",sep="")) & file.exists(paste(Dir,"Reactome.DB.Names.txt",sep=""))){
	R2Genes<-read.table(paste(Dir,"Reactome.DB.GeneList.txt",sep=""),header=TRUE,sep="\t")
	ReactomeTerms<-read.table(paste(Dir,"Reactome.DB.Names.txt",sep=""),header=TRUE,sep="\t",quote="\"")
}else{
	library("reactome.db")#kegg database to extract the reactome data gene set & set Name
	ReactomeTerms<-toTable(reactome.db::reactomePATHID2NAME)
	ReactomeEntrez<-toTable(reactome.db::reactomeEXTID2PATHID)
	ReactomeEntrez$Gene_Symbol<-mapIds(org.Mm.eg.db,keys=as.character(ReactomeEntrez$gene_id),
	                                   column="SYMBOL",keytype="ENTREZID",multiVals="first")
	R2Genes<-ReactomeEntrez[,c("DB_ID","Gene_Symbol")]
	ReactomeTerms<-ReactomeTerms[ReactomeTerms$DB_ID %in% unique(ReactomeEntrez$DB_ID),]
	write.table(R2Genes,paste(Dir,"Reactome.DB.GeneList.txt",sep=""),sep="\t",quote=FALSE,row.names=FALSE)
	write.table(ReactomeTerms,paste(Dir,"Reactome.DB.Names.txt",sep=""),sep="\t",quote=FALSE,row.names=FALSE)
}


#Kegg Part
#if(file.exists(paste(Dir,"Kegg.GeneList.txt",sep="")) & file.exists(paste(Dir,"Kegg.Names.txt",sep=""))){
#	Kegg2Genes<-read.table(paste(Dir,"Kegg.GeneList.txt",sep=""),header=TRUE,sep="\t")
#	KeggTerms<-read.table(paste(Dir,"Kegg.Names.txt",sep=""),header=TRUE,sep="\t",quote="\"")
#}else{
#	library("KEGG.db")#kegg database to extract the kegg Name
#	Genes2Kegg<-toTable(org.Mm.egPATH)
#	KeggTerms<-toTable(KEGG.db::KEGGPATHID2NAME)
#	Genes2Kegg$Gene_Symbol<-mapIds(org.Mm.eg.db,keys=as.character(Genes2Kegg$gene_id),
#		column="SYMBOL",keytype="ENTREZID",multiVals="first")
#	Kegg2Genes<-Genes2Kegg[,c("path_id","Gene_Symbol")]
#	write.table(Kegg2Genes,paste(Dir,"Kegg.GeneList.txt",sep=""),sep="\t",quote=FALSE,row.names=FALSE)
#	write.table(KeggTerms,paste(Dir,"Kegg.Names.txt",sep=""),sep="\t",quote=FALSE,row.names=FALSE)
#}

#Panther Part
if(file.exists(paste(Dir,"Panther.GeneList.txt",sep="")) & file.exists(paste(Dir,"Panther.Names.txt",sep=""))){
	P2Genes<-read.table(paste(Dir,"Panther.GeneList.txt",sep=""),header=TRUE,sep="\t")
	PTerms<-read.table(paste(Dir,"Panther.Names.txt",sep=""),header=TRUE,sep="\t",quote="\"")
}else{
	library("PANTHER.db")#Panther DB to extract the Panther DB data gene set & set Name
	PantherInfo<-AnnotationDbi::select(x=PANTHER.db,keys="MOUSE",columns=c("ENTREZ","PATHWAY_TERM","PATHWAY_ID"), keytype="SPECIES")
	PantherInfo<-PantherInfo[!is.na(PantherInfo$PATHWAY_ID),]
	PantherInfo$Gene_Symbol<-as.vector(mapIds(org.Mm.eg.db,keys=as.character(PantherInfo$ENTREZ),
	                                column="SYMBOL",keytype="ENTREZID",multiVals="first"))
	P2Genes<-unique(PantherInfo[,c("PATHWAY_ID","Gene_Symbol")])
	P2Genes<- apply(P2Genes,2,as.character)
	PTerms<-unique(PantherInfo[,c("PATHWAY_ID","PATHWAY_TERM")])
	PTerms<- apply(PTerms,2,as.character)
	write.table(P2Genes,paste(Dir,"Panther.GeneList.txt",sep=""),sep="\t",quote=FALSE,row.names=FALSE)
	write.table(PTerms,paste(Dir,"Panther.Names.txt",sep=""),sep="\t",quote=FALSE,row.names=FALSE)
}

########################################################################
#	AllTestGoKeggPanther
#		-Test all available ressources for enrichement of a list of gene
#		-Export all results in txt files 1 per tested ressources
#		-Can also export a xlsx file with a tab per table
#			-if the xlsx already exist, it will be deleted to be able to write a new one
#		-will only export a file if the results table is non empty i.e. it found something
#
#	Usage
#		-Supposed to be called directly
#		
#	Input
#		-GeneList: gene of interest to be tested for enrichment
#			format of genes: official gene symbol i.e. the name of the gene on NCBI
#			R format: vector of string
#			Case sensitive
#
#		-BackGround: gene of Uninterest to be set as background
#			format of genes: official gene symbol i.e. the name of the gene on NCBI
#			R format: vector of string
#			Case sensitive

#
#		-PopName: Name of the tested list of gene
#			will be use as root name for all the outputed files either .txt or .xlsx
#			R format: String
#
#		-outputXLSX: Flag to ouput xlsx file or not
#			R format: Boolean
#
#	Output
#		-txt files
#			pop name with a suffixes according to the tested feature
#				BP Gene Ontology biological process
#				CC Gene Ontology cellular component
#				MF Gene Ontology molecular function
#				Kegg KEGG pathway
#				Panther Panther database
#				Reactome Reactome database
#		-xlsx file
#			popname with a .xlsx file extension will be created
#				each tab represent tested database
#
#	Return
#		Nothing
#
AllTestGoKeggPanther<-function(GeneList,BackGround=NULL,PopName,outputXLSX=FALSE){
  if (outputXLSX) {
    if (file.exists(paste(PopName, ".xlsx", sep = ""))) {
      file.remove(paste(PopName, ".xlsx", sep = ""))
    }
  }
  BP <-
    clusterProfiler::enricher(
      GeneList,
      universe = BackGround,
      TERM2GENE = BP2Genes,
      TERM2NAME = GoTerms.BP,
      minGSSize = 1,
      pAdjustMethod = "fdr"
    )
  MF <-
    clusterProfiler::enricher(
      GeneList,
      universe = BackGround,
      TERM2GENE = MF2Genes,
      TERM2NAME = GoTerms.MF,
      minGSSize = 1,
      pAdjustMethod = "fdr"
    )
  CC <-
    clusterProfiler::enricher(
      GeneList,
      universe = BackGround,
      TERM2GENE = CC2Genes,
      TERM2NAME = GoTerms.CC,
      minGSSize = 1,
      pAdjustMethod = "fdr"
    )
#  Kegg <-
#    clusterProfiler::enricher(
#      GeneList,
#      universe = BackGround,
#      TERM2GENE = Kegg2Genes,
#      TERM2NAME = KeggTerms,
#      minGSSize = 1,
#      pAdjustMethod = "fdr"
#    )
  Panther <-
    clusterProfiler::enricher(
      GeneList,
      universe = BackGround,
      TERM2GENE = P2Genes,
      TERM2NAME = PTerms,
      minGSSize = 1,
      pAdjustMethod = "fdr"
    )
  Reactome <-
    clusterProfiler::enricher(
      GeneList,
      universe = BackGround,
      TERM2GENE = R2Genes,
      TERM2NAME = ReactomeTerms,
      minGSSize = 1,
      pAdjustMethod = "fdr"
    )
	DESCRIPTION<-vector()
	if(dim(data.frame(BP))[1]>0){
		write.table(BP[order(BP$Count,decreasing=TRUE),],
		paste(PopName,".BP.txt",sep=""),sep="\t",quote=FALSE,row.names=FALSE)
		if(outputXLSX){
			xlsx::write.xlsx(BP[order(BP$Count,decreasing=TRUE),],
				paste(PopName,".xlsx",sep=""), sheetName="Biological Process", 
				col.names=TRUE, row.names=FALSE, append=TRUE)
		}
		DESCRIPTION<-c(DESCRIPTION,as.vector(BP$Description))
	}
	if(dim(data.frame(CC))[1]>0){
		write.table(CC[order(CC$Count,decreasing=TRUE),],
			paste(PopName,".CC.txt",sep=""),sep="\t",quote=FALSE,row.names=FALSE)
		if(outputXLSX){
			xlsx::write.xlsx(CC[order(CC$Count,decreasing=TRUE),],
				paste(PopName,".xlsx",sep=""), sheetName="Cellular Component", 
				col.names=TRUE, row.names=FALSE, append=TRUE)
		}
		DESCRIPTION<-c(DESCRIPTION,as.vector(CC$Description))
	}
	if(dim(data.frame(MF))[1]>0){
		write.table(MF[order(MF$Count,decreasing=TRUE),],
			paste(PopName,".MF.txt",sep=""),sep="\t",quote=FALSE,row.names=FALSE)
		if(outputXLSX){
			xlsx::write.xlsx(MF[order(MF$Count,decreasing=TRUE),],
				paste(PopName,".xlsx",sep=""), sheetName="Molecular Function", 
				col.names=TRUE, row.names=FALSE, append=TRUE)
		}
		DESCRIPTION<-c(DESCRIPTION,as.vector(MF$Description))
	}
#	if(dim(data.frame(Kegg))[1]>0){
#		write.table(Kegg[order(Kegg$Count,decreasing=TRUE),],
#			paste(PopName,".Kegg.txt",sep=""),sep="\t",quote=FALSE,row.names=FALSE)
#		if(outputXLSX){
#			xlsx::write.xlsx(x=Kegg[order(Kegg$Count,decreasing=TRUE),],
#				file=paste(PopName,".xlsx",sep=""), sheetName="KEGG", 
#				col.names=TRUE, row.names=FALSE, append=TRUE)
#		}
#		DESCRIPTION<-c(DESCRIPTION,as.vector(Kegg$Description))
#	}
	if(dim(data.frame(Panther))[1]>0){
		write.table(Panther[order(Panther$Count,decreasing=TRUE),],
			paste(PopName,".Panther.txt",sep=""),sep="\t",quote=FALSE,row.names=FALSE)
		if(outputXLSX){
			xlsx::write.xlsx(Panther[order(Panther$Count,decreasing=TRUE),],
				paste(PopName,".xlsx",sep=""), sheetName="Panther", 
				col.names=TRUE, row.names=FALSE, append=TRUE)
		}
		DESCRIPTION<-c(DESCRIPTION,as.vector(Panther$Description))
	}
	if(dim(data.frame(Reactome))[1]>0){
		write.table(Reactome[order(Reactome$Count,decreasing=TRUE),],
			paste(PopName,".Reactome.txt",sep=""),sep="\t",quote=FALSE,row.names=FALSE)
		if(outputXLSX){
			xlsx::write.xlsx(Reactome[order(Reactome$Count,decreasing=TRUE),],
				paste(PopName,".xlsx",sep=""), sheetName="Reactome", 
				col.names=TRUE, row.names=FALSE, append=TRUE)
		}
		DESCRIPTION<-c(DESCRIPTION,gsub("human:","",as.vector(Reactome$Description)))
	}
	DESCRIPTION<-gsub("regulation","",DESCRIPTION)
	DESCRIPTION<-gsub("process","",DESCRIPTION)
}	

########################################################################
#	OneTestGoKeggPanther
#		-Test one of the available ressources for enrichement of a list of gene
#		-Return a dataframe obtained by the Enricher function
#
#	Usage
#		-Supposed to be called by a function that will use a data frame
#			-a shiny app for example
#
#	Input
#		-GeneList: gene of interest to be tested for enrichment
#			format of genes: official gene symbol i.e. the name of the gene on NCBI
#			R format: vector of string
#			Case sensitive
#
#		-BackGround: gene of Uninterest to be set as background
#			format of genes: official gene symbol i.e. the name of the gene on NCBI
#			R format: vector of string
#			Case sensitive
#
#		-Ressource: Name of the tested ressource
#			R format: String among a predefined vector of possibles values
#				BP Gene Ontology biological process
#				CC Gene Ontology cellular component
#				MF Gene Ontology molecular function
#				Kegg KEGG pathway
#				Panther Panther database
#				Reactome Reactome database
#
#	Output
#		nothing
#
#	Return
#		Data frame of the enricher function
#			-can be an empty data frame
#			-one line per significant gene set
#			-columns:
#				1 ID: Code name of the tested gene set
#				2 Description: human readable name og the tested gene set
#				3 GeneRatio: [in Gene List and also in gene set]/[in Gene List]
#				4 BgRatio: [not in Gene List but in gene set]/[all the genes of the all the gene sets]
#				5 pvalue: pvalue of the hypergeometric test
#				6 p.adjust: ajusted pvalue using FDR
#				7 qvalue:
#				8 geneID:Name of the genes in Gene List ans also in the Gene Set
#				9 Count: how many genes are present in both GeneList & the GeneSet
#
OneTestGoKeggPanther<-function(GeneList,
Ressource=c("BP","MF","CC","reactome","Panther","biogrid"),BackGround=NULL,AdjPvalCutoff=1,pretty=FALSE){
	#return(matrix(0,3,3))
	if(Ressource=="BP"){
		Enrich<-enricher(GeneList,universe=BackGround,TERM2GENE=BP2Genes,TERM2NAME=GoTerms.BP,
			minGSSize=1,pAdjustMethod="fdr",pvalueCutoff=AdjPvalCutoff)
	}else if(Ressource=="MF"){
		Enrich<-enricher(GeneList,universe=BackGround,TERM2GENE=MF2Genes,TERM2NAME=GoTerms.MF,
			minGSSize=1,pAdjustMethod="fdr",pvalueCutoff=AdjPvalCutoff)
	}else if(Ressource=="CC"){
		Enrich<-enricher(GeneList,universe=BackGround,TERM2GENE=CC2Genes,TERM2NAME=GoTerms.CC,
			minGSSize=1,pAdjustMethod="fdr",pvalueCutoff=AdjPvalCutoff)
	}else if(Ressource=="KEGG"){
		Enrich<-enricher(GeneList,universe=BackGround,TERM2GENE=Kegg2Genes,TERM2NAME=KeggTerms,
			minGSSize=1,pAdjustMethod="fdr",pvalueCutoff=AdjPvalCutoff)
	}else if(Ressource=="Panther"){
		Enrich<-enricher(GeneList,universe=BackGround,TERM2GENE=P2Genes,TERM2NAME=PTerms,
			minGSSize=1,pAdjustMethod="fdr",pvalueCutoff=AdjPvalCutoff)
	}else if(Ressource=="reactome"){
		Enrich<-enricher(GeneList,universe=BackGround,TERM2GENE=R2Genes,TERM2NAME=ReactomeTerms,
			minGSSize=1,pAdjustMethod="fdr",pvalueCutoff=AdjPvalCutoff)
	}else if(Ressource=="biogrid"){
	  Enrich<-enricher(GeneList,universe=BackGround,TERM2GENE=BioGrid2Gene,TERM2NAME=BG2Terms,
	                   minGSSize=1,pAdjustMethod="fdr",pvalueCutoff=AdjPvalCutoff)
	}
  
	if(dim(Enrich)[1]>0 & !is.null(Enrich)){
		Enrich<-data.frame(Enrich)
		rownames(Enrich)<-NULL
		if(pretty){
			Enrich$pvalue[!is.na(Enrich$pvalue)]<-formatC(Enrich$pvalue[!is.na(Enrich$pvalue)],format = "e", digits = 2)
			Enrich$p.adjust[!is.na(Enrich$p.adjust)]<-formatC(Enrich$p.adjust[!is.na(Enrich$p.adjust)],format = "e", digits = 2)
			Enrich$qvalue[!is.na(Enrich$qvalue)]<-formatC(Enrich$qvalue[!is.na(Enrich$qvalue)],format = "e", digits = 2)
			Enrich$geneID<-gsub("/"," ",Enrich$geneID)
			Enrich<-Enrich[order(Enrich$Count,decreasing=TRUE),]
			Enrich<-Enrich[,c("ID",
			                  "Description",
			                  "GeneRatio",
			                  "BgRatio",
			                  "pvalue",
			                  "p.adjust",
			                  "Count",
			                  "geneID")]
		}
		return(Enrich)
	}else{
		return(NULL)
	}
}

########################################################################
#	PlotString
#		-Test a list of gene for interaction network
#
#	Usage
#		-Supposed to be called by a function that will use a data frame
#		-Can also be called directly by do not I/O any file
#
#	Input
#		-GeneList: gene of interest to be tested for enrichment
#			format of genes: official gene symbol i.e. the name of the gene on NCBI
#			R format: vector of string
#			Case sensitive
#		-if the GeneList is bigger than 400 elements, only the 400 first of the list will be taken
#
#	Output
#		graph of interaction as in string DB with some statistics about the network
#
#	Return
#		Nothing
#
PlotString<-function(GeneList){
	stringDB<-STRINGdb$new(version="10",species=9606,score_threshold=0, input_directory="" )
	Mapped <- stringDB$map( data.frame("gene"=GeneList),
	"gene", removeUnmappedRows = TRUE ,quiet=TRUE)
	if(dim(Mapped)[1]>400){
		Mapped<-Mapped[1:400,]
		Title<-"400 Firsts"
		stringDB$plot_network(Mapped$STRING_id,add_link=TRUE,add_summary=TRUE)
	}else{
		stringDB$plot_network(Mapped$STRING_id,add_link=TRUE,add_summary=TRUE)
	}
}

