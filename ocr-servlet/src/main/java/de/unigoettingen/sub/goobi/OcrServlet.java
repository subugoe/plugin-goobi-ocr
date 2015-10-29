package de.unigoettingen.sub.goobi;

import java.io.IOException;
import java.io.PrintWriter;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.io.IOUtils;

/**
 * Servlet implementation class OcrServlet
 */
public class OcrServlet extends HttpServlet {
	private static final long serialVersionUID = 1L;
       
	/**
	 * @see HttpServlet#doGet(HttpServletRequest request, HttpServletResponse response)
	 */
	protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
		PrintWriter out = response.getWriter();
		
		String subpathToImages = request.getParameter("path");
		String imagesRange = request.getParameter("imgrange");
		if (subpathToImages == null || imagesRange == null) {
			out.println("Error: missing parameters. The servlet must be called e.g. with ?path=<path-to-images>&imgrange=1-20");
			return;
		}
		
		String completePathToImages = getInitParameter("pathToMetadata") + subpathToImages;
		if (completePathToImages.endsWith("/")) {
			completePathToImages = completePathToImages.substring(0, completePathToImages.length() - 1);
		}
		
		String pathToTei = completePathToImages + ".tei.xml";
		
		if (imagesRange.contains("-")) {
			String[] fromTo = imagesRange.split("-");
			int from = Integer.parseInt(fromTo[0]);
			int to = Integer.parseInt(fromTo[1]);
			printPage(from, to, pathToTei, out);
		} else {
			out.println("<pre>");
			int pageNumber = Integer.parseInt(imagesRange);
			printPage(pageNumber, pageNumber, pathToTei, out);
			out.println("</pre>");
		}
				
	}

	private void printPage(int pageFrom, int pageTo, String pathToTeiFile, PrintWriter out) throws IOException {
		String pageExtractorScript = getInitParameter("pageExtractorScript");
		
		Process proc = new ProcessBuilder(pageExtractorScript, pathToTeiFile, ""+pageFrom, ""+pageTo).start();
		
		out.println(IOUtils.toString(proc.getInputStream()));
		
		String errorMessage = IOUtils.toString(proc.getErrorStream());
		if (errorMessage != null && !errorMessage.equals("")) {
			out.println("ERROR:");
			out.println(errorMessage);
		}
	}

	/**
	 * @see HttpServlet#doPost(HttpServletRequest request, HttpServletResponse response)
	 */
	protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
	}

}
