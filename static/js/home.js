$(document).ready(function(){
  SmoothScrollLinks();
  setTeamActions();
});

function setTeamActions(){
  $('.personBox').click(function(){
    //first get the paragraph content
    $imgObj = $(this).find('img');
    $pObj = $(this).find('p');
    $divDesc = $(this).find('div.descr');
    //stick it into the modal
    $('.pImgBox').empty();
    $('.pImgBox').append($imgObj.clone());
    $('.pImgBox').append($divDesc.clone());

    $('.writeupBox').empty();
    $('.writeupBox').append($pObj.clone());

    //display
    $('.peoplOverlay').css('display', 'block');
  });

  $('.closer').click(function(){
    $(this).parent().parent().css('display', 'none');
  });
}

function SmoothScrollLinks()
{
  $('a[href^="#"]').on('click', function(event) {
    var target = $(this.getAttribute('href'));
    var windowHeight = $(window).outerHeight();
    if(target.length) {
      event.preventDefault();
        $('html, body').stop().animate({
            scrollTop: target.offset().top
        }, 1000);
    }
  });
}